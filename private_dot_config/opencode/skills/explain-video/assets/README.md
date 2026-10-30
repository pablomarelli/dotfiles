# {{TITLE}}

Open [index.html](index.html) for the **Psychopomp film**, or play [{{SLUG}}-psychopomp.mp4]({{SLUG}}-psychopomp.mp4). It is a DURATION-second, 1920x1080, 60-fps film with synthetic narration, N chapter buttons, and the transcript. It explains WHAT_IT_EXPLAINS.

Built with [Kit Langton's Psychopomp](https://github.com/kitlangton/psychopomp) pinned to `1813f2f1d4170679a514cb16e8678f88210b9ac4`. The written design is DESIGN_DOC_LINK_OR_REMOVE.

## Scope and important distinctions

- WHAT THIS FILM IS AND IS NOT (for example: it explains the software, not a live production audit).
- TERMS DEFINED AT FIRST USE.
- EXAMPLE VALUES THAT ARE ILLUSTRATIVE, NOT REAL.

## Chapters

1. **CHAPTER TITLE.** One or two sentences that state the claim of the chapter, with the real identifiers it shows.
2. **CHAPTER TITLE.** ...

## Source checks

Checked DATE against BRANCH_OR_COMMIT. Paths are relative to `REPO_ROOT`.

| Claim | Source |
| --- | --- |
| CLAIM SHOWN IN THE FILM | `path/to/file.py`, `function_name`; commit `abc1234`. |

## Regenerate the film

Run from `REPO_ROOT`. Requirements: Rust (cargo), FFmpeg/FFprobe with `libx264`, an Apple silicon Mac (for the GPU renderer and local narration), Node.js 20+, and `uvx`. No paid API or credentials are used by default.

```sh
node docs/explainers/{{SLUG}}/psychopomp/render.mjs
```

Narration uses the open-source [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) model locally through `mlx-audio`, with the `am_michael` voice. `psychopomp/narration/script.json` holds the spoken text and a `pronounce` map of IPA overrides for words Kokoro mispronounces. Word timings come from Whisper small English, and every visual beat waits for a phrase in that transcript, so re-voicing re-times the film. Set `VOICE` to choose another Kokoro voice, `TTS_ENGINE=say` for a quick macOS draft, or `TTS_ENGINE=elevenlabs` with `ELEVENLABS_API_KEY` and `VOICE=<voice id>`.

Check the source and player:

```sh
cargo fmt --manifest-path docs/explainers/{{SLUG}}/psychopomp/Cargo.toml --check
cargo test --locked --manifest-path docs/explainers/{{SLUG}}/psychopomp/Cargo.toml
cargo clippy --locked --manifest-path docs/explainers/{{SLUG}}/psychopomp/Cargo.toml --all-targets -- -D warnings
node docs/explainers/{{SLUG}}/psychopomp/verify.mjs
```

Review evidence: REPLACE WITH WHAT WAS INSPECTED (frames per chapter, decode, measured loudness).
