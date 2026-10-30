// Voice-over for narration/script.json: one MP3 plus Whisper word timings per clip,
// loudness-normalized to -16 LUFS, with a narration.json manifest for Narration::load.
//
// Engines (TTS_ENGINE):
//   kokoro      default; free local Kokoro-82M through mlx-audio (Apple silicon). VOICE=am_michael
//   say         macOS built-in voice, instant draft. VOICE=Samantha
//   elevenlabs  paid; needs ELEVENLABS_API_KEY and VOICE=<voice id>. ELEVENLABS_MODEL=eleven_v4
//
// script.json: { "pronounce"?: { "Word": "/ipa/" }, "clips": [{ "id", "title", "text" }] }
// `pronounce` applies Kokoro's inline phoneme syntax to words it would otherwise mispronounce.
// Clips whose text, engine, voice, and Whisper model are unchanged are not regenerated.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const slug = path.basename(path.dirname(root));
const dir = path.join(root, 'narration');
const work = process.env.RENDER_TMP ?? path.join(process.env.HOME, `.tmp/opencode/${slug}-psychopomp`);
mkdirSync(work, { recursive: true });
const script = JSON.parse(readFileSync(path.join(dir, 'script.json')));
const manifestPath = path.join(dir, 'narration.json');
const previous = existsSync(manifestPath) ? JSON.parse(readFileSync(manifestPath)).clips : [];
const clips = [];
const engine = process.env.TTS_ENGINE ?? 'kokoro';
if (!['kokoro', 'say', 'elevenlabs'].includes(engine)) throw new Error(`Unknown TTS_ENGINE '${engine}'`);
const voice = process.env.VOICE ?? { kokoro: 'am_michael', say: 'Samantha', elevenlabs: undefined }[engine];
if (engine === 'elevenlabs' && (!voice || !process.env.ELEVENLABS_API_KEY)) throw new Error('ElevenLabs needs VOICE=<voice id> and ELEVENLABS_API_KEY');
const kokoro = 'mlx-community/Kokoro-82M-bf16';
const elevenModel = process.env.ELEVENLABS_MODEL ?? 'eleven_v4';
const model = process.env.WHISPER_MODEL ?? 'mlx-community/whisper-small.en-mlx';
const pronounce = Object.entries(script.pronounce ?? {});
const spoken = text => engine === 'kokoro'
  ? pronounce.reduce((out, [word, ipa]) => out.replace(new RegExp(`\\b${word}\\b`, 'g'), `[${word}](${ipa})`), text)
  : text;
// Vocal directions in square brackets are for ElevenLabs only.
const plain = text => text.replace(/\[[^\]]*\]\s*/g, '');
const run = (exe, args) => execFileSync(exe, args, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });

const ids = new Set();
for (const clip of script.clips) {
  if (!/^[a-z0-9-]+$/.test(clip.id)) throw new Error(`Clip id '${clip.id}' must be lowercase letters, digits, and dashes`);
  if (ids.has(clip.id)) throw new Error(`Duplicate clip id '${clip.id}'`);
  ids.add(clip.id);
  const hash = createHash('sha256').update(JSON.stringify({ text: spoken(clip.text), engine, voice, model, elevenModel })).digest('hex');
  const file = `${clip.id}.mp3`;
  const words = `${clip.id}.words.json`;
  const cached = previous.find(item => item.id === clip.id && item.hash === hash);
  if (cached && existsSync(path.join(dir, file)) && existsSync(path.join(dir, words))) {
    clips.push(cached);
    continue;
  }
  console.log(`Narrating ${clip.id} (${engine})`);
  const text = path.join(work, `${clip.id}.txt`);
  const raw = path.join(work, engine === 'elevenlabs' ? `${clip.id}.raw.mp3` : `${clip.id}.wav`);
  writeFileSync(text, plain(clip.text));
  if (engine === 'kokoro') {
    run('uvx', ['--python', '3.12', '--from', 'mlx-audio==0.5.7', '--with', 'misaki[en]==0.9.4', '--with', 'pip',
      'mlx_audio.tts.generate', '--model', kokoro, '--voice', voice, '--lang_code', 'a', '--text', spoken(plain(clip.text)),
      '--output_path', work, '--file_prefix', clip.id, '--join_audio', '--audio_format', 'wav']);
  } else if (engine === 'say') {
    run('say', ['-v', voice, '-f', text, '-o', raw, '--data-format=LEI16@48000']);
  } else {
    if (clip.text.length > 2000) throw new Error(`Clip '${clip.id}' exceeds the 2,000-character ElevenLabs dialogue limit`);
    const response = await fetch('https://api.elevenlabs.io/v1/text-to-dialogue?output_format=mp3_44100_192', {
      method: 'POST',
      headers: { 'xi-api-key': process.env.ELEVENLABS_API_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model_id: elevenModel, inputs: [{ voice_id: voice, text: clip.text }], settings: script.settings, use_pvc_as_ivc: false }),
      signal: AbortSignal.timeout(120_000),
    });
    if (!response.ok) throw new Error(`ElevenLabs HTTP ${response.status}: ${await response.text()}`);
    if (!response.headers.get('content-type')?.startsWith('audio/')) throw new Error('ElevenLabs did not return audio');
    writeFileSync(raw, Buffer.from(await response.arrayBuffer()));
  }
  run('ffmpeg', ['-y', '-loglevel', 'error', '-i', raw, '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', '-ar', '48000', '-ac', '1', '-b:a', '160k', path.join(dir, file)]);
  run('uvx', ['--from', 'mlx-whisper', 'mlx_whisper', '--model', model, '--word-timestamps', 'True', '--condition-on-previous-text', 'False', '--output-format', 'json', '--output-dir', work, '--output-name', clip.id, path.join(dir, file)]);
  const transcript = JSON.parse(readFileSync(path.join(work, `${clip.id}.json`), 'utf8').replace(/\bNaN\b/g, 'null'));
  let previousEnd = 0;
  const wordTimings = transcript.segments.flatMap(segment => segment.words).map(word => {
    const start = Math.max(previousEnd, word.start);
    const end = Math.max(start, word.end);
    previousEnd = end;
    return { word: word.word.trim(), start, end };
  });
  const duration = Number(run('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', path.join(dir, file)]).trim());
  // Whisper can silently drop a final segment; phrase cues after it would then be missing.
  const gaps = wordTimings.map((word, i) => word.start - (wordTimings[i - 1]?.end ?? 0));
  if (duration - (wordTimings.at(-1)?.end ?? 0) > 1.5 || Math.max(...gaps) > 3) throw new Error(`Transcript of ${clip.id} skips part of its audio; try WHISPER_MODEL=mlx-community/whisper-large-v3-mlx or reword the clip`);
  if (engine === 'elevenlabs' && wordTimings.some(word => /^\[/.test(word.word))) throw new Error(`Clip ${clip.id} spoke a vocal direction tag aloud`);
  writeFileSync(path.join(dir, words), JSON.stringify({ wordTimings }, null, 2) + '\n');
  const label = { kokoro: `Kokoro ${voice}`, say: `macOS say ${voice}`, elevenlabs: `ElevenLabs ${elevenModel} ${voice}` }[engine];
  clips.push({ id: clip.id, file, words, durationNanos: Math.round(duration * 1e9), hash, engine: label, model });
  // Save each completed clip so an interrupted run can resume.
  writeFileSync(manifestPath, JSON.stringify({ clips: [...clips, ...previous.filter(item => !clips.some(done => done.id === item.id))] }, null, 2) + '\n');
}
writeFileSync(manifestPath, JSON.stringify({ clips }, null, 2) + '\n');
console.log(`Narration ready: ${clips.length} clips, ${(clips.reduce((sum, clip) => sum + clip.durationNanos, 0) / 1e9).toFixed(1)}s of speech`);
