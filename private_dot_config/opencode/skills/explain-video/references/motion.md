# Motion: rules every beat must follow

Condensed from Kit Langton's `explainer-motion` skill. The full text with constants
and formulas is in the engine checkout at
`$PSYCHOPOMP_ROOT/.agents/skills/explainer-motion/{SKILL.md,TECHNIQUES.md}`.
Read TECHNIQUES.md when a beat needs a number this page does not give.

## Energy has a source

Every beat moves energy from one point to another. It gathers at a source,
travels, and is absorbed where it lands. Nothing lights up, flashes, or moves
without a cause the viewer can point to. When a beat feels flat or noisy, ask
where its energy comes from and where it goes.

## Rules

- **Quiet at rest.** Idle wires and cards are still and matte. The scaffold's
  `begin` sets every beam's `draw` and `flow` to 0 and every other element's
  `opacity` to 0. Nothing is visible until the narration calls for it.
- **One focal action.** Establish the source, follow the signal, read the result.
  Do not run two packets at the same time unless the story is "two things at once".
- **Light is local.** A packet lights only the border near it. An arrival colors
  a card from its socket. Use `s.land("id")`, never a whole-card flash.
- **Receivers do not scale.** Geometry moves on entrances (`settle_in`, `orb_in`)
  and on deliberate rigs, not on hits.
- **Color means something.** Signals are near-white with the tone in the trail.
  `Error` (red) is failure. One `Accent` is the thing to follow. Everything else
  is `Muted` or `Plain`.
- **Reaction follows contact.** A reply never prepares before its request
  arrives: `v.at("replies").not_before(request_span.reply())`.
- **Continuity.** Keep actors in the same positions across chapters. Transform
  instead of cutting: the same store, the same API card, the same client orb.
- **Physical metaphor.** A dropped request falls, a killed process shatters
  (`s.to("orb.shatter", ..)`), a timeout is a ring closing, data flows on wires.
- **Camera.** `establish` to open, `glide("camera.z", ..)` to push in on the
  resolution, `frame` a group when the story narrows, `follow` a packet only
  when its journey is the story. Shake (`jolt`) only on impact. Never orbit to
  decorate.
- **Rhythm.** Stagger entrances about 120 ms apart. Land impacts on the spoken
  word. Prepare beats (settle a card, draw a wire) 0.3 to 0.6 s early.

## The core beats and the Stage call for each

| Beat | Call | Default seconds |
| --- | --- | --- |
| Card enters | `s.settle_in("card")` | built in |
| Hero orb enters | `s.orb_in("orb", OrbEntrance::HERO)` | built in |
| Label or form appears | `s.fade_in("id", 1.0, 0.4)` | 0.4 |
| Wire draws | `s.connect("beam", 0.45)` | 0.4 to 0.5 |
| Message travels and lands | `s.send("pkt", 0.7).then(s.land("target"))` | 0.6 to 0.8 |
| Reply travels | reversed packet, same `send`/`land`, `.not_before(span.reply())` | 0.6 to 0.8 |
| State changes | `s.swap_status("card", [0, 1], 0.4)` | 0.4 |
| Impact | `.also(s.jolt([0.0, 1.0], 0.5))` with the status swap | 0.5 |
| Push aside | `s.dim(["card"], 0.7, 0.4)` (cards); `s.to("form.opacity", 0.35, 0.4)` (forms, orbs) | 0.4 |
| Storage appears | `s.fade_in("store", 1.0, 0.4)` and `s.morph("store", 1, 1.1)` together | 1.1 |
| Fix replays | `s.rewind(0.8)` then the same beats resolving differently | 0.8 |
| Resolution | `s.glide("camera.z", 40.0, 2.0)` | 2.0 |

## Pacing per chapter (15 to 30 s of speech)

- 0.0 to 0.4 s: header types in, chip shows.
- 0.3 to 1.5 s: hero actor enters, then the other actors stagger in as they are named.
- Body: one send/land or state change per sentence, on the word.
- Last sentence: footer types in, camera pushes in or pulls back.
- Chapters join with `ReelTransitionStyle::Dip` over 0.65 s.

## Review before the full render

1. `node render.mjs --sheet t1,t2,t3,...` with one time per visual beat (read the
   `.words.json` times, add the 1.1 s lead). Look at the sheet. Check: no text
   overlap, no element outside the frame, the right status shown, the focal
   action visible at thumbnail size.
2. `node render.mjs --cue <chapter>` for one chapter with audio. Watch for
   packets that start before their wire is drawn, replies that leave before
   requests land, and forms that morph while invisible.
3. Only then the full render. State in the README which frames and clips were
   inspected. Endpoint stills cannot prove smooth motion.
