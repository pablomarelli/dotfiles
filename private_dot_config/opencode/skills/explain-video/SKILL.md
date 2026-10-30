---
name: explain-video
description: >
  Build a narrated explainer video (film, motion graphic, animated walkthrough) of
  an architecture, a code path, a PR or change, a request flow, a data flow, or a
  business flow with Kit Langton's Psychopomp engine. Use whenever the user asks
  for a video, film, animation, movie, reel, or visual walkthrough that explains
  how something works, or wants to turn a design doc, flow, or codebase into a
  video people can watch. Output is a 1080p60 MP4 with free local narration, a
  browser player with chapters and transcript, and a README with source checks,
  all committed under docs/explainers/ in the user's repo.
---

# Explain video

A narrated Psychopomp film: 4 to 7 chapters, 90 to 180 seconds, every visual beat
cued to a spoken phrase. The pipeline is proven; your job is the facts, the
script, and the choreography. Read [references/story.md](references/story.md),
[references/motion.md](references/motion.md), and
[references/api-cheatsheet.md](references/api-cheatsheet.md) before authoring.
[references/film-layout.md](references/film-layout.md) lists files, commands,
and environment variables.

Requirements: Apple silicon Mac, `cargo`, `node` 20+, `ffmpeg`/`ffprobe`, `uvx`.
Narration is free and local (Kokoro through mlx-audio, Whisper for word timings).
No API key is needed. The first render builds the engine (minutes) and downloads
two small models.

## Rules that are not negotiable

- **Facts before script.** Every narrated sentence maps to a row in a facts table
  (claim, file, function, commit). Unverified claims stay out of the film.
- **Never end a turn while a render runs in the background.** Run renders in the
  foreground with a long timeout (full film: 10 to 15 minutes; set `timeout` to
  at least 900000 ms).
- **Review frames before the full render.** A contact sheet and one `--cue`
  chapter with audio, inspected by eye, before `render.mjs` with no flags.
- **Anchors are transcript words.** Read `<id>.words.json` before writing
  `v.at("..")`. A missing phrase panics in `cargo run`.
- **Do not reset an existing engine checkout.** `render.mjs` refuses a rev
  mismatch; point `PSYCHOPOMP_ROOT` elsewhere instead.
- **Real identifiers only.** Endpoint paths, table names, function names, env var
  names from the code. Example values (a budget, a feed id) are labeled as examples
  in chapter 1 and in the README.

## Workflow

### 1. Establish the facts

Read the code, the PR diff, or the design doc the user points at. Produce a facts
table in your working notes:

| Claim | Source |
| --- | --- |
| The tracker writes the receipt and the window in one transaction | `apps/tracker/postback.py`, `record_payout`; commit `abc1234` |

Decide the question the film answers and what it is not (a production audit, a
proposal, a tutorial). Pick 4 to 7 chapter ideas, one idea each, with shared
actors across chapters. Confirm the title, org/scope label, and slug with the
user if they are not obvious from the request.

### 2. Scaffold

```sh
node ~/.config/opencode/skills/explain-video/scripts/scaffold.mjs <repo>/docs/explainers/<slug> \
  --title "CPA caps across Apptness" --org APPTNESS --subtitle "One line under the player."
```

The slug is the directory name (lowercase, digits, dashes). Existing files are
kept unless `--force`. The scaffold contains a working two-chapter starter film
(`overview`, `request`): replace its clips and chapter functions, keep its
helpers (`card`, `label`, `orb`, `wire`, `packet`, `reply`, `store`, `begin`,
`show`, `footer`).

### 3. Write the script

Edit `psychopomp/narration/script.json`: one clip per chapter with `id`
(matches the chapter fn name), `title` (player button text), `text` (15 to 30 s
spoken, plain short sentences, numbers spelled as spoken). Add `pronounce` IPA
entries for names Kokoro will mangle. Follow story.md for voice and structure.

Narrate and read the timings before touching Rust:

```sh
node <film>/psychopomp/narrate.mjs
python3 -c "import json,sys;[print(' '.join(f\"{w['word']}@{w['start']:.1f}\" for w in json.load(open(p))['wordTimings'])) for p in sys.argv[1:]]" <film>/psychopomp/narration/*.words.json
```

Listen to one clip (`open <film>/psychopomp/narration/<id>.mp3`). Fix
pronunciation with IPA, not by misspelling the word.

### 4. Author the chapters

In `psychopomp/src/main.rs`, one fn per clip, built as the starter does:

```rust
fn postback(n: &Narration) -> Result<ScenePlan> {
    let (mut sc, s, v) = begin(n, "postback", "03", "a paid postback arrives", "apptness-trk-view", vec![
        orb("partner", 330.0, 450.0, 110.0),
        label("partner-name", 330.0, 615.0, "partner server", Plain),
        card("view", 940.0, 450.0, "/track", "apptness-trk-view"),
        wire("post", "partner", "view"),
        packet("payout", "post", "POST /track?payout=4.00"),
    ])?;
    sc.at(seconds(0.35), s.orb_in("partner", OrbEntrance::HERO));
    show(&mut sc, &s, "partner-name", seconds(0.9));
    sc.at(v.at("posts back").early(seconds(0.4)), s.settle_in("view"));
    sc.at(v.at("posts back"), s.connect("post", 0.45).then(s.send("payout", 0.7)).then(s.land("view")));
    footer(&mut sc, "one postback / one receipt", v.at("one receipt"))?;
    Ok(sc.finish()?)
}
```

Then list the fns in `build`. Positions are 1920x1080 pixels; keep shared actors
at the same coordinates in every chapter. Apply motion.md to each beat: prepare
early, land on the word, replies `.not_before(span.reply())`, one focal action.
A form (storage) needs both `show` and `morph`. `dim` is for cards; forms and
orbs fade with `s.to("id.opacity", ..)`. Run `cargo fmt` and
`cargo clippy --all-targets -- -D warnings` on the crate as you go.

### 5. Review stills and one chapter

```sh
node <film>/psychopomp/render.mjs --skip-narration --sheet 3,8,12,20,27,35
node <film>/psychopomp/render.mjs --skip-narration --cue postback
```

Pick sheet times from the word timings plus the 1.1 s lead and the preceding
chapter durations (`cargo run` prints the total; `psychopomp plan inspect
film.reel.json` prints segment spans). Open the sheet PNG with the `read` tool
and look: text overlap, elements off frame, wrong status, invisible focal action,
packets before wires, replies before requests. Watch the cue MP4 if anything
looks timing-related. Fix and repeat until every chapter has been seen.

### 6. Render, verify, document

```sh
node <film>/psychopomp/render.mjs                    # foreground, long timeout
node <film>/psychopomp/verify.mjs
cargo fmt --manifest-path <film>/psychopomp/Cargo.toml --check
cargo test --locked --manifest-path <film>/psychopomp/Cargo.toml
cargo clippy --locked --manifest-path <film>/psychopomp/Cargo.toml --all-targets -- -D warnings
```

`verify.mjs` checks 1080p60 h264 + AAC, exact duration, full decode, loudness in
-20..-12 LUFS, and the player (chapter seeks, transcript, no autoplay, no console
errors, no overflow at 1440/768/390 px). Then fill `README.md`: what the film
explains and is not, chapter list with the identifiers each shows, the facts
table as "Source checks", and the review evidence (which sheets and clips you
inspected, measured LUFS). Replace every ALL-CAPS placeholder.

### 7. Deliver

Report the player path (`docs/explainers/<slug>/index.html`), the MP4 path,
duration, chapter count, and anything you could not verify. Commit the film
directory including `Cargo.lock`, the MP4, poster, VTT, and player data. Do not
commit `target/`, mp3s, or `film.reel.json` (already ignored).

## When something fails

| Symptom | Fix |
| --- | --- |
| `cargo run` panics "no phrase ... in clip" | Anchor words differ from the transcript. Read `<id>.words.json`; use `v.at_any` or reword the clip. |
| `plan validate`: unknown property `x.dim` | Channel not valid for that element kind. See the channel table in api-cheatsheet.md. |
| Element never appears | `begin` hides everything; add `show(..)` (and `morph` for forms). |
| narrate.mjs: "Transcript ... skips part of its audio" | `WHISPER_MODEL=mlx-community/whisper-large-v3-mlx node narrate.mjs`, or shorten the clip. |
| Word mispronounced | Add `"Word": "/ipa/"` to `pronounce` in script.json; the clip hash changes and it is re-voiced. |
| `PSYCHOPOMP_ROOT ... is at <rev>` | Another film pinned a different rev. Leave it; the default path is per rev, so unset `PSYCHOPOMP_ROOT`. |
| verify.mjs loudness out of range | Narration is normalized per clip; check `ffmpeg -af loudnorm` on one mp3, then re-narrate with `--force` by deleting `narration.json`. |
| Need a Stage feature not in the cheatsheet | `grep -n "pub fn" $PSYCHOPOMP_ROOT/crates/psychopomp/src/score.rs` and read `SCENE_PLANS.md` there. |

## Optional: ElevenLabs narration

`TTS_ENGINE=elevenlabs VOICE=<voice id> ELEVENLABS_API_KEY=... node render.mjs`.
Model defaults to `eleven_v4`; vocal directions in square brackets
(`[measured, clear voice]`) are allowed in `text` and stripped for other engines.
Mention the cost before running it; Kokoro is the default for a reason.
