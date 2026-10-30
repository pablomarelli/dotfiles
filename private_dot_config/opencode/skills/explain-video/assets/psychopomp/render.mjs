// Build and render with Kit Langton's native Psychopomp engine.
//
//   node render.mjs                      narrate, compile the reel, render the full film, write player data
//   node render.mjs --frame 31.5         narrate, compile, render one still (PNG) for review
//   node render.mjs --range 30..33       narrate, compile, render a time window (MP4) for review
//   node render.mjs --cue <chapter-id>   narrate, compile, render one chapter (MP4) for review
//   node render.mjs --skip-narration ... reuse the narration already on disk
//
// Review outputs go to $RENDER_TMP/preview/ (default ~/.tmp/opencode/<slug>-psychopomp/preview/).
// The pinned engine revision is read from Cargo.toml so it is declared once.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const output = path.dirname(root);
const slug = path.basename(output);
const home = process.env.HOME;
const revision = readFileSync(path.join(root, 'Cargo.toml'), 'utf8').match(/psychopomp\s*=\s*\{[^}]*rev\s*=\s*"([0-9a-f]{40})"/)?.[1];
if (!revision) throw new Error('Cargo.toml must pin psychopomp with a 40-character rev');
const engine = process.env.PSYCHOPOMP_ROOT ?? path.join(home, `.tmp/opencode/psychopomp-${revision.slice(0, 7)}`);
const target = process.env.CARGO_TARGET_DIR ?? path.join(root, 'target');
const work = process.env.RENDER_TMP ?? path.join(home, `.tmp/opencode/${slug}-psychopomp`);
const theme = process.env.THEME ?? 'neutral';
const movie = path.join(output, `${slug}-psychopomp.mp4`);

const args = process.argv.slice(2);
const flag = name => { const i = args.indexOf(name); return i === -1 ? undefined : args[i + 1]; };
const frame = flag('--frame');
const sheet = flag('--sheet');
const range = flag('--range');
const cue = flag('--cue');
const preview = [frame, sheet, range, cue].some(value => value !== undefined);

const run = (exe, list, cwd = root) => execFileSync(exe, list, { cwd, stdio: 'inherit', env: { ...process.env, CARGO_BUILD_JOBS: process.env.CARGO_BUILD_JOBS ?? '4' } });

if (!existsSync(engine)) {
  mkdirSync(path.dirname(engine), { recursive: true });
  run('git', ['clone', 'https://github.com/kitlangton/psychopomp.git', engine]);
  // This checkout is new. Never reset an existing engine checkout.
  run('git', ['switch', '--detach', revision], engine);
}
const actual = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: engine, encoding: 'utf8' }).trim();
if (actual !== revision) throw new Error(`PSYCHOPOMP_ROOT (${engine}) is at ${actual}, Cargo.toml pins ${revision}. Existing checkout left untouched; point PSYCHOPOMP_ROOT elsewhere or change the pin.`);

if (!args.includes('--skip-narration')) run(process.execPath, [path.join(root, 'narrate.mjs')]);
// The first run writes Cargo.lock; commit it so later runs are reproducible.
const locked = existsSync(path.join(root, 'Cargo.lock')) ? ['--locked'] : [];
run('cargo', ['run', ...locked, '--manifest-path', path.join(root, 'Cargo.toml'), '--target-dir', target]);
run('cargo', ['build', '--locked', '--release', '-p', 'psychopomp-render', '--target-dir', path.join(engine, 'target')], engine);
const renderer = path.join(engine, 'target/release/psychopomp');
const reel = path.join(root, 'film.reel.json');
run(renderer, ['plan', 'validate', reel], engine);

if (preview) {
  const dir = path.join(work, 'preview');
  mkdirSync(dir, { recursive: true });
  if (frame !== undefined) {
    const png = path.join(dir, `frame-${frame.replace(/[^0-9.]/g, '_')}.png`);
    run(renderer, ['plan', 'frame', reel, frame, png, '--theme', theme, '--shutter'], engine);
    console.log(`Wrote ${png}`);
  } else if (sheet !== undefined) {
    // Contact sheet: up to three stills per row, scaled to 1920 px wide.
    const times = sheet.split(',').map(value => value.trim()).filter(Boolean);
    const stills = times.map(time => {
      const png = path.join(dir, `sheet-${time.replace(/[^0-9.]/g, '_')}.png`);
      run(renderer, ['plan', 'frame', reel, time, png, '--theme', theme, '--shutter'], engine);
      return png;
    });
    const rows = [];
    for (let i = 0; i < stills.length; i += 3) rows.push(stills.slice(i, i + 3));
    const inputs = stills.flatMap(png => ['-i', png]);
    const columns = Math.min(3, stills.length);
    const filters = rows.map((row, r) => {
      const joined = row.length === 1 ? `[${r * 3}]null` : `${row.map((_, c) => `[${r * 3 + c}]`).join('')}hstack=${row.length}`;
      const pad = row.length < columns ? `,pad=${columns * 1920}:1080:0:0:black` : '';
      return `${joined}${pad}[r${r}]`;
    });
    const stack = rows.length === 1 ? '[r0]scale=1920:-1' : `${rows.map((_, r) => `[r${r}]`).join('')}vstack=${rows.length},scale=1920:-1`;
    const out = path.join(dir, `sheet-${times.map(time => time.replace(/[^0-9.]/g, '_')).join('-')}.png`);
    run('ffmpeg', ['-y', '-loglevel', 'error', ...inputs, '-filter_complex', `${filters.join(';')};${stack}`, out]);
    console.log(`Wrote ${out}`);
  } else {
    const name = range !== undefined ? `range-${range.replace(/[^0-9.]/g, '_')}` : `cue-${cue}`;
    const mp4 = path.join(dir, `${name}.mp4`);
    run(renderer, ['plan', 'render', reel, mp4, ...(range !== undefined ? ['--range', range] : ['--cue', cue]), '--theme', theme], engine);
    console.log(`Wrote ${mp4}`);
  }
  process.exit(0);
}

run(renderer, ['plan', 'render', reel, movie, '--theme', theme], engine);

const plan = JSON.parse(readFileSync(reel));
const script = JSON.parse(readFileSync(path.join(root, 'narration/script.json')));
let end = 0;
const chapters = plan.segments.map(segment => {
  const start = end - segment.transitionNanos / 1e9;
  end = start + segment.plan.durationNanos / 1e9;
  const clip = script.clips.find(item => item.id === segment.plan.id);
  if (!clip) throw new Error(`Reel segment ${segment.plan.id} has no clip in narration/script.json`);
  return { id: clip.id, title: clip.title, text: clip.text, start, end };
});

// Poster: a still from inside the first chapter unless POSTER_SECONDS says otherwise.
const posterAt = process.env.POSTER_SECONDS ?? Math.min(chapters[0].end - 1, chapters[0].start + 10.5).toFixed(2);
const poster = path.join(work, 'poster.png');
mkdirSync(path.dirname(poster), { recursive: true });
run(renderer, ['plan', 'frame', reel, String(posterAt), poster, '--theme', theme, '--shutter'], engine);
run('ffmpeg', ['-y', '-loglevel', 'error', '-i', poster, '-q:v', '2', path.join(output, 'psychopomp-poster.jpg')]);

writeFileSync(path.join(output, 'psychopomp-player-data.js'), `globalThis.PSYCHOPOMP_CHAPTERS = ${JSON.stringify(chapters, null, 2)};\n`);
const stamp = seconds => new Date(Math.round(seconds * 1000)).toISOString().slice(11, 23);
const vtt = chapters.map((chapter, index) => `${index + 1}\n${stamp(chapter.start)} --> ${stamp(chapters[index + 1]?.start ?? chapter.end)}\n${chapter.title}`).join('\n\n');
writeFileSync(path.join(output, 'psychopomp-chapters.vtt'), `WEBVTT\n\n${vtt}\n`);
console.log(`Wrote ${movie} (${end.toFixed(2)}s, ${chapters.length} chapters)`);
