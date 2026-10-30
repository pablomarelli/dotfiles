# Psychopomp API cheatsheet (rev 1813f2f)

Everything here was used in a rendered film or read from the engine source at
`$PSYCHOPOMP_ROOT/crates/psychopomp/src/` (`score.rs`, `stage.rs`, `stage/camera.rs`,
`narration.rs`). When in doubt, grep that source; it is on disk after the first render.

## Imports the scaffold uses

```rust
use psychopomp::{
    author::{PlanBuilder, seconds},
    caption::{CaptionAlign, CaptionSpanPlan},
    narration::{Narration, Spoken},
    plan::{ReelPlan, ReelSegmentPlan, ReelTransitionStyle, ScenePlan},
    rolling::RollingNumberPlan,
    score::{Beat, Caption, CueTime, RollingNumber, Stage},
    stage::{OrbEntrance, StageElement as E, StagePlan, StagePost},
    tone::Tone::{self, Accent, Error, Muted, Plain, Success},
};
```

Time is `u64` nanoseconds. Use `seconds(1.5)`; never raw integers.

## Narration (phrase-driven clock)

```rust
let narration = Narration::load(&root.join("narration"))?;            // reads narration.json
let reading = narration.reading(seconds(1.1), [("clip-id", seconds(1.0))])?; // lead-in, (clip, tail gap)
let mut scene = PlanBuilder::new("clip-id", reading.duration());
let [v] = reading.place(&mut scene);                                   // Spoken handle
v.at("plain spoken words")          // u64: when the phrase starts. PANICS if the transcript lacks it.
v.at_any(&["sig term", "sigterm"])  // first match among spellings Whisper may produce
v.at_after("again", "the second")   // search only after an earlier phrase (repeated words)
v.at_every("go")                    // Vec<u64>, one per occurrence
v.start(); v.end(); v.words()       // clip bounds on the plan clock, word iterator
```

Anchor rules: plain words that exist in `<id>.words.json`, unique inside the clip,
no acronyms, no punctuation. Number words match digits ("twenty seven" matches "27").
Everything cued from `v.at(..)` is offset by the lead-in, so a word at 11.7 s in the
MP3 is at 12.8 s on the plan clock with a 1.1 s lead.

## Cue-time arithmetic (`CueTime` on `u64` and `Span`)

```rust
v.at("x").early(seconds(0.4))        // start 0.4 s before the word
v.at("x").not_before(prev.reply())   // never before the previous beat's natural reply time
let span = sc.at(time, beat);        // returns a Span
span.reply()                         // when a response to this beat may launch
```

## Beats and combinators (`score::Beat`)

```rust
sc.at(time, beat);                        // schedule
a.then(b)                                  // b after a ends
a.then_after(seconds(0.2), b)              // with a gap
a.also(b)                                  // together
a.with(b)                                  // b subordinate to a
a.on_end(b)                                // react when a ends
beat.after(seconds(0.3)); beat.early(seconds(0.3)); beat.hold_for(seconds(1.0))
score::stagger(seconds(0.12), items, |item| ...)   // ripple through a list
score::each(items, |item| ...)                     // all at once
chain!(a, b, c); all!(a, b, c); at!(..)            // macros
```

## Stage elements (`StageElement`, aliased `E`)

Frame is 1920x1080 pixels; `at` is `[x, y, z]` with z toward the camera (labels use z -2).

```rust
E::card(id, [x, y, 0.0], [360.0, 116.0], "Title").statuses(&[("line", Muted), ("200 OK", Success)])
E::orb(id, [x, y, 0.0], radius).tone(Plain)                 // particle sphere: a person, a client, a service
E::beam(id, "from-id", "to-id").tone(Muted)                  // a wire between two elements
E::packet(id, "beam-id").labeled("text").tone(Accent)        // travels along a beam
E::packet(id, "beam-id").reversed().labeled("reply").tone(Success)
E::label(id, [x, y, -2.0], 23.0, &[("text", Tone)])         // free text, size in px
E::ring(id, [x, y, 0.0], radius)
// Particle form (storage, cluster, ...). Shapes: plane, box, sphere, lattice, cylinder, torus, helix, knot.
serde_json::from_value::<E>(json!({
  "kind": "form", "id": id, "at": [x, y, 0], "tone": "plain", "points": 560,
  "shapes": [{ "shape": "plane", "size": [210, 160] }, { "shape": "box", "size": [160, 160, 160], "edges": 0.55 }]
}))
```

Channels each kind accepts (use with `stage.channel/set/to/glide`):

| Kind | Channels |
| --- | --- |
| Card | opacity x y z scale blur glow flash alarm dim status status-from swap content cool damage glitch cut ghost spinner release mark charge dissolve scan |
| Orb | opacity x y z scale blur rotation burst shatter pulse hurt spin charge |
| Beam | opacity sweep port draw break flow emphasis surge twang |
| Packet | opacity age flight |
| Label | opacity x y z scale typed |
| Ring | opacity x y z scale sweep expand |
| Form | opacity x y z scale blur rotation spin pitch roll morph burst shatter pulse hurt solid |
| Shape | opacity x y z scale rotation blur draw fill emphasis flash |
| Path | opacity draw trim flow emphasis surge |

`dim` is card-only. Fade a form or orb with `s.to("id.opacity", 0.35, 0.4)`.

## Stage beats (`score::Stage`, handle `s`)

```rust
let stage = Stage::declare(&mut scene, "stage", &StagePlan { post: StagePost::RESTRAINED, elements })?;
s.channel("id.opacity", 0.0)             // initial value (the scaffold hides everything at t=0)
s.orb_in("client", OrbEntrance::HERO)    // hero entrance for an orb
s.settle_in("card")                      // rigid panel settles in (PANEL spring)
s.fade_in("id", 1.0, 0.4); s.fade_out("id", 0.4)
s.connect("beam", 0.45)                  // draw the wire
s.send("packet", 0.7).then(s.land("target-id"))   // travel, then absorb at the target
s.swap_status("card", [0, 1], 0.4)       // cross-fade statuses index 0 -> 1
s.dim(["card-a", "card-b"], 0.7, 0.4)    // cards only; 0.0 restores
s.morph("form", 1, 1.1)                  // form shape index 0 -> 1
s.jolt([0.0, 1.0], 0.6)                  // screen kick for an impact
s.glide("camera.z", 40.0, 2.0)           // any channel, minimum-jerk
s.to("id.prop", value, secs); s.set("id.prop", value); s.spring("id.prop", v, Feel::SNAP)
s.hit("id.flash", 1.0, 0.0)              // impulse then rest
s.rewind(0.8)                            // VHS rewind of the whole stage
s.disconnect("beam", 0.4); s.twang("beam"); s.glitch("card", [1.0, 2.0, 3.0])
s.dissolve("card"); s.materialize("card", 0.6); s.scan("card", 0.8)
```

Forms are hidden by the scaffold's `begin`: reveal with `fade_in` and `morph` together.

## Camera (`s.camera()`, `Move::{Spring(secs), Glide(secs), Ease(secs, Ease), Cut}`)

```rust
let cam = s.camera();
sc.at(0, cam.establish(90.0, 1.7));                       // opening dolly from `back` px
cam.frame(&["api", "store"], 150.0, Move::Spring(1.4))    // frame a group with padding
cam.push_in(200.0, Move::Glide(2.0)); cam.pull_back(200.0, Move::Spring(1.6))
cam.follow("packet-id", Move::Spring(0.7)); cam.release(Move::Spring(1.2))
cam.focus_on("card", Move::Spring(1.0)); cam.aperture(0.6, Move::Spring(1.0))
cam.orbit("store", [0.0, 0.4], Move::Glide(3.0)); cam.dolly_zoom("api", 500.0, Move::Glide(2.4))
cam.whip(&["client"], 160.0, 0.6); cam.handheld(1.0, 4.0); cam.drift("store", 3.0)
```

## Captions, callouts, rolling numbers

```rust
let header = Caption::header(&mut sc, "01", "chapter title")?;   sc.at(seconds(0.15), header.type_in(65.0, 0.4));
let chip = Caption::chip(&mut sc, "chapter", Muted, "repo / scope")?; sc.at(seconds(0.3), chip.show());
let foot = Caption::footer(&mut sc, "takeaway", &[("one line summary", Muted)])?; sc.at(t, foot.type_in(60.0, 0.4));
caption.hide(); caption.move_to("anchor")

let n = RollingNumber::declare(&mut sc, "spend",
    RollingNumberPlan::new([960.0, 270.0], 40.0, "0").aligned(CaptionAlign::Center).tone(Accent)
        .prefix(vec![CaptionSpanPlan::new("spend  $", Muted)]).suffix(vec![CaptionSpanPlan::new(" / $10", Muted)]).chip())?;
sc.at(seconds(0.5), n.show()); sc.at(v.at("four"), n.roll("4"));

// Callout pinned to a Stage element (see scenes/callouts/src/lib.rs for more anchors).
use psychopomp::callout::{CalloutAnchorPlan, CalloutPlan, CalloutSide};
let c = Callout::declare(&mut sc, "retries", &CalloutPlan::new(
    CalloutAnchorPlan::Stage { id: "api".into(), element: "api".into(), edge: CalloutSide::Top, side: None },
    vec![CaptionSpanPlan::new("retries ", Plain), CaptionSpanPlan::new("3x", Accent)],
).side(CalloutSide::TopRight).elbow().reach(72.0))?;
sc.at(v.at("retries"), c.show()); c.emphasize(); c.hide()
```

## Reel assembly and output

```rust
ReelSegmentPlan { transition_nanos: seconds(0.65), transition_style: ReelTransitionStyle::Dip,
                  transition_focus: None, transition_wipe: None, plan }
// Styles: Crossfade, Dip, Zoom, Wipe, JCut, LCut, Push(dir), Slide(dir), Whip(dir), ...
let reel = ReelPlan { version: ReelPlan::VERSION, id: "slug".into(), segments };
reel.validate()?; reel.duration_nanos();
fs::write("film.reel.json", serde_json::to_string_pretty(&reel)?)?;
```

Rust-side `validate()` does not catch every mistake; the renderer's `plan validate`
(run by `render.mjs`) also checks channel names per element kind.

## Renderer CLI (`$PSYCHOPOMP_ROOT/target/release/psychopomp`)

```sh
psychopomp plan validate film.reel.json
psychopomp plan inspect  film.reel.json                   # actors, channels, cues
psychopomp plan frame    film.reel.json 31.5 out.png --theme neutral --shutter
psychopomp plan render   film.reel.json out.mp4 --theme neutral [--cue <chapter-id> | --range 30..33]
psychopomp plan present  film.reel.json                   # interactive window
```

Output is always 1920x1080 at 60 fps, h264 + AAC. Themes: neutral (default here),
opencode, original, evergreen, tokyo-night, black.

## Deeper reading in the checkout

- `SCENE_PLANS.md`: "Build An Explainer" table, "Make A Narrated Explainer Reel", transitions, recipes.
- `DSL.md`, `EFFECTS.md`, `ARCHITECTURE.md`.
- `scenes/opencode-jr-architecture/` (architecture film, one module per chapter),
  `scenes/pr-walkthrough/` (PR film with animated diffs), `scenes/config-migration/` (smallest).
- `.agents/skills/psychopomp/STORY.md`, `.agents/skills/explainer-motion/TECHNIQUES.md`.
