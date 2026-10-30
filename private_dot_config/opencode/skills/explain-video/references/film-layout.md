# Film directory layout, generated files, and environment variables

## Directory

The film lives beside the code it explains, under `docs/explainers/<slug>/`. The
directory name is the slug: lowercase letters, digits, dashes. It becomes the
MP4 name, the reel id, and the crate name (`<slug>-film`).

```
docs/explainers/<slug>/
  README.md                      what the film explains, chapters, source checks, how to regenerate
  index.html                     browser player: chapter buttons, transcript, download link
  <slug>-psychopomp.mp4          the film, 1920x1080, 60 fps, h264 + AAC          (generated, commit it)
  psychopomp-poster.jpg          still used as the video poster                   (generated, commit it)
  psychopomp-chapters.vtt        chapter track for the <video> element            (generated, commit it)
  psychopomp-player-data.js      chapter starts, titles, and transcript           (generated, commit it)
  psychopomp/
    Cargo.toml                   pins psychopomp by git rev; the single source of truth for the engine version
    Cargo.lock                   written by the first run; commit it
    .gitignore                   target/, mp3s, words.json, narration.json, film.reel.json
    src/main.rs                  the film: helpers, one chapter fn per clip, reel assembly, one test
    narration/
      script.json                clips (id, title, text) and the `pronounce` IPA map; the only hand-written narration file
      <id>.mp3                   normalized speech per clip                        (generated, ignored)
      <id>.words.json            Whisper word timings per clip                     (generated, ignored)
      narration.json             manifest with hashes; lets narrate.mjs skip unchanged clips (generated, ignored)
    render.mjs                   narrate, compile, validate, render, write player data
    narrate.mjs                  TTS + loudnorm + Whisper for every changed clip
    verify.mjs                   ffprobe/decode/loudness checks and a Playwright pass over index.html
    film.reel.json               compiled reel that the renderer reads            (generated, ignored)
```

Scratch output goes to `$RENDER_TMP` (default `~/.tmp/opencode/<slug>-psychopomp/`):
TTS wavs, Whisper json, `preview/` stills and clips, the poster PNG.

## Commands (run from anywhere)

```sh
node docs/explainers/<slug>/psychopomp/render.mjs --frame 12.5          # one still
node docs/explainers/<slug>/psychopomp/render.mjs --sheet 3,8,12,20     # contact sheet, 3 per row
node docs/explainers/<slug>/psychopomp/render.mjs --cue <chapter-id>    # one chapter, with audio
node docs/explainers/<slug>/psychopomp/render.mjs --range 30..33        # a time window
node docs/explainers/<slug>/psychopomp/render.mjs                       # full film + player files
node docs/explainers/<slug>/psychopomp/verify.mjs
```

Add `--skip-narration` when `script.json` has not changed (saves the uvx startup).
`render.mjs` always runs `narrate.mjs` first otherwise; unchanged clips are cached
by hash, so this is cheap after the first run.

Every `render.mjs` call also:

1. Clones the engine to `$PSYCHOPOMP_ROOT` if missing and checks it is at the
   pinned rev. It never resets an existing checkout; a mismatch is an error.
2. `cargo run` on the film crate, which writes `film.reel.json`.
3. Builds the renderer (`psychopomp-render`, release) inside the engine checkout.
4. `psychopomp plan validate film.reel.json`. This catches channel errors the
   Rust `reel.validate()` misses.

## Environment variables

| Variable | Default | Used by |
| --- | --- | --- |
| `PSYCHOPOMP_ROOT` | `~/.tmp/opencode/psychopomp-<rev7>` | render.mjs: engine checkout |
| `CARGO_TARGET_DIR` | `<film>/psychopomp/target` | render.mjs |
| `CARGO_BUILD_JOBS` | `4` | render.mjs (keeps the machine usable during builds) |
| `RENDER_TMP` | `~/.tmp/opencode/<slug>-psychopomp` | render.mjs, narrate.mjs |
| `THEME` | `neutral` | render.mjs (`opencode`, `original`, `evergreen`, `tokyo-night`, `black`) |
| `POSTER_SECONDS` | ~10.5 s into chapter 1 | render.mjs |
| `TTS_ENGINE` | `kokoro` | narrate.mjs (`kokoro`, `say`, `elevenlabs`) |
| `VOICE` | `am_michael` / `Samantha` / none | narrate.mjs (Kokoro voice, say voice, ElevenLabs voice id) |
| `WHISPER_MODEL` | `mlx-community/whisper-small.en-mlx` | narrate.mjs (`mlx-community/whisper-large-v3-mlx` if a clip is skipped) |
| `ELEVENLABS_API_KEY`, `ELEVENLABS_MODEL` | none, `eleven_v4` | narrate.mjs |
| `PLAYWRIGHT_MODULE`, `CHROME_PATH` | auto | verify.mjs |

## Toolchain

- Apple silicon Mac: the renderer uses Metal; Kokoro and Whisper run on MLX.
- `cargo` (Rust 2024 edition), `node` 20+, `ffmpeg` and `ffprobe` with libx264,
  `uvx` (from uv), `git`.
- First run downloads the Kokoro and Whisper models (a few hundred MB) and
  builds the renderer (several minutes). Later runs reuse all of it.

## Kokoro voices

American English: `am_michael` (default, calm male), `am_adam`, `am_eric`,
`am_fenrir`, `am_liam`, `am_onyx`, `af_heart`, `af_bella`, `af_nova`, `af_sarah`.
British: `bm_george`, `bm_lewis`, `bf_emma`, `bf_isabella`. Keep one voice per film.

## Pronunciation

`script.json` has `"pronounce": { "Word": "/ipa/" }`. `narrate.mjs` rewrites each
match to Kokoro's inline phoneme form `[Word](/ipa/)` before synthesis; the
transcript still shows the plain word, so anchors are unaffected. Known needs:
`"Redis": "/ɹˈɛdɪs/"`. Listen to each new clip once (`open <id>.mp3`) and add
entries for names and acronyms that sound wrong.

## Cue clock

`begin` places the clip with a 1.1 s lead and a 1.0 s tail. A word that
`<id>.words.json` puts at 11.7 s is at 12.8 s on the chapter clock. Chapter N
starts at the sum of earlier chapter durations minus the 0.65 s dips;
`render.mjs` writes the exact starts to `psychopomp-player-data.js`.
