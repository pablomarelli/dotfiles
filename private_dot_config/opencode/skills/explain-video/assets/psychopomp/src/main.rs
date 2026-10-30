//! {{TITLE}} as a Psychopomp Stage film.
//! Each chapter has its own clock; phrase cues come from measured narration.
//! Replace the two starter chapters with the real story. Keep the helpers.
use std::{fs, path::Path};

use anyhow::Result;
use psychopomp::{
    author::{PlanBuilder, seconds},
    narration::{Narration, Spoken},
    plan::{ReelPlan, ReelSegmentPlan, ReelTransitionStyle, ScenePlan},
    score::{Beat, Caption, CueTime, Stage},
    stage::{OrbEntrance, StageElement as E, StagePlan, StagePost},
    tone::Tone::{self, Accent, Error, Muted, Plain, Success},
};
use serde_json::json;

// ---------------------------------------------------------------------------
// Element helpers. Coordinates are 1920x1080 frame pixels; z is depth.
// ---------------------------------------------------------------------------

fn card(id: &str, x: f32, y: f32, title: &str, detail: &str) -> E {
    E::card(id, [x, y, 0.0], [360.0, 116.0], title).statuses(&[(detail, Muted)])
}

fn label(id: &str, x: f32, y: f32, text: &str, tone: Tone) -> E {
    E::label(id, [x, y, -2.0], 23.0, &[(text, tone)])
}

fn orb(id: &str, x: f32, y: f32, radius: f32) -> E {
    E::orb(id, [x, y, 0.0], radius).tone(Plain)
}

fn wire(id: &str, from: &str, to: &str) -> E {
    E::beam(id, from, to).tone(Muted)
}

fn packet(id: &str, wire: &str, text: &str) -> E {
    E::packet(id, wire).labeled(text).tone(Accent)
}

fn reply(id: &str, wire: &str, text: &str, tone: Tone) -> E {
    E::packet(id, wire).reversed().labeled(text).tone(tone)
}

/// A dark particle cube represents durable storage. `morph(id, 1, secs)`
/// turns the flat plane into the box.
fn store(id: &str, x: f32, y: f32) -> E {
    serde_json::from_value(json!({
        "kind": "form", "id": id, "at": [x, y, 0], "tone": "plain", "points": 560,
        "shapes": [
            { "shape": "plane", "size": [210, 160] },
            { "shape": "box", "size": [160, 160, 160], "edges": 0.55 }
        ]
    }))
    .expect("valid particle store")
}

// ---------------------------------------------------------------------------
// Chapter helpers.
// ---------------------------------------------------------------------------

/// Open a chapter: place its narration clip, declare the Stage with every
/// element hidden, and type the header and chip. Returns the scene, the stage
/// handle, and the spoken clip whose phrases drive every beat.
fn begin<'a>(
    narration: &'a Narration,
    id: &str,
    number: &str,
    title: &str,
    chip: &str,
    elements: Vec<E>,
) -> Result<(PlanBuilder, Stage, Spoken<'a>)> {
    let reading = narration.reading(seconds(1.1), [(id, seconds(1.0))])?;
    let mut scene = PlanBuilder::new(id, reading.duration());
    let [voice] = reading.place(&mut scene);
    let plan = StagePlan {
        post: StagePost::RESTRAINED,
        elements,
    };
    let stage = Stage::declare(&mut scene, "stage", &plan)?;
    // Connections are matte and still until an explicitly sent message travels.
    for element in &plan.elements {
        match element {
            E::Beam { .. } | E::Path { .. } => {
                scene.at(0, stage.channel(format!("{}.draw", element.id()), 0.0));
                scene.at(0, stage.channel(format!("{}.flow", element.id()), 0.0));
            }
            E::Packet { .. } => {}
            _ => {
                scene.at(0, stage.channel(format!("{}.opacity", element.id()), 0.0));
            }
        }
    }
    let header = Caption::header(&mut scene, number, title)?;
    let status = Caption::chip(&mut scene, "chapter", Muted, chip)?;
    scene.at(seconds(0.15), header.type_in(65.0, 0.4));
    scene.at(seconds(0.3), status.show());
    let camera = stage.camera();
    scene.at(0, camera.establish(90.0, 1.7));
    Ok((scene, stage, voice))
}

fn show(scene: &mut PlanBuilder, stage: &Stage, id: &str, at: u64) {
    scene.at(at, stage.fade_in(id, 1.0, 0.4));
}

fn footer(scene: &mut PlanBuilder, text: &str, at: u64) -> Result<()> {
    let caption = Caption::footer(scene, "takeaway", &[(text, Muted)])?;
    scene.at(at, caption.type_in(60.0, 0.4));
    Ok(())
}

// ---------------------------------------------------------------------------
// Chapters. One function per narration clip; the id must match script.json.
// ---------------------------------------------------------------------------

fn overview(n: &Narration) -> Result<ScenePlan> {
    let (mut sc, s, v) = begin(
        n,
        "overview",
        "01",
        "what this film explains",
        "{{ORG}} / {{TITLE}}",
        vec![
            orb("client", 400.0, 470.0, 110.0),
            label("client-name", 400.0, 630.0, "client", Plain),
            card("api", 960.0, 470.0, "API", "answers requests"),
            store("store", 1520.0, 470.0),
            label("store-name", 1520.0, 630.0, "store", Plain),
            wire("call", "client", "api"),
            wire("read", "api", "store"),
            packet("request", "call", "request"),
            packet("lookup", "read", "lookup"),
            label(
                "slow",
                960.0,
                800.0,
                "what happens when the store is slow",
                Accent,
            ),
        ],
    )?;
    sc.at(seconds(0.35), s.orb_in("client", OrbEntrance::HERO));
    show(&mut sc, &s, "client-name", seconds(0.9));
    sc.at(
        v.at("sends a request").early(seconds(0.4)),
        s.settle_in("api"),
    );
    sc.at(
        v.at("sends a request"),
        s.connect("call", 0.45)
            .then(s.send("request", 0.7))
            .then(s.land("api")),
    );
    // A form is hidden by `begin`; reveal it with `show` and let it `morph` into its box.
    let store_in = v.at("reads from a store").early(seconds(0.5));
    show(&mut sc, &s, "store", store_in);
    sc.at(store_in, s.morph("store", 1, 1.1));
    show(&mut sc, &s, "store-name", v.at("reads from a store"));
    sc.at(
        v.at("reads from a store"),
        s.connect("read", 0.45)
            .then(s.send("lookup", 0.7))
            .then(s.land("store")),
    );
    show(&mut sc, &s, "slow", v.at("store is slow"));
    sc.at(v.at("store is slow"), s.glide("camera.z", 40.0, 2.0));
    footer(&mut sc, "three parts / one request", v.at("three parts"))?;
    Ok(sc.finish()?)
}

fn request(n: &Narration) -> Result<ScenePlan> {
    let (mut sc, s, v) = begin(
        n,
        "request",
        "02",
        "one request, end to end",
        "happy path, then a slow store",
        vec![
            orb("client", 400.0, 470.0, 110.0),
            label("client-name", 400.0, 630.0, "client", Plain),
            E::card("api", [960.0, 470.0, 0.0], [360.0, 116.0], "API").statuses(&[
                ("waiting", Muted),
                ("200 OK", Success),
                ("503 retry later", Error),
            ]),
            store("store", 1520.0, 470.0),
            label("store-name", 1520.0, 630.0, "store", Plain),
            wire("call", "client", "api"),
            wire("read", "api", "store"),
            packet("request", "call", "GET /records/42"),
            packet("lookup", "read", "SELECT ... WHERE id = 42"),
            reply("row", "read", "row 42", Success),
            reply("ok", "call", "200 OK", Success),
            reply("busy", "call", "503", Error),
            packet("retry", "call", "retry"),
        ],
    )?;
    sc.at(seconds(0.3), s.orb_in("client", OrbEntrance::HERO));
    show(&mut sc, &s, "client-name", seconds(0.8));
    sc.at(seconds(0.5), s.settle_in("api"));
    show(&mut sc, &s, "store", seconds(0.7));
    sc.at(seconds(0.7), s.morph("store", 1, 1.1));
    show(&mut sc, &s, "store-name", seconds(1.2));
    let called = sc.at(
        v.at("calls the API"),
        s.connect("call", 0.4)
            .then(s.send("request", 0.7))
            .then(s.land("api")),
    );
    let asked = sc.at(
        v.at("asks the store").not_before(called.reply()),
        s.connect("read", 0.4)
            .then(s.send("lookup", 0.7))
            .then(s.land("store")),
    );
    sc.at(
        v.at("returns the row").not_before(asked.reply()),
        s.send("row", 0.7).then(s.land("api")),
    );
    sc.at(
        v.at("answers the client"),
        s.swap_status("api", [0, 1], 0.4)
            .also(s.send("ok", 0.7).then(s.land("client"))),
    );
    // `dim` is a card channel; a form fades with `to("<id>.opacity", ..)`.
    sc.at(
        v.at("store is slow").early(seconds(0.4)),
        s.to("store.opacity", 0.35, 0.4),
    );
    sc.at(
        v.at("API returns"),
        s.swap_status("api", [1, 2], 0.4)
            .also(s.jolt([0.0, 1.0], 0.5))
            .also(s.send("busy", 0.7).then(s.land("client"))),
    );
    sc.at(
        v.at("client retries"),
        s.send("retry", 0.7)
            .then(s.land("api"))
            .then(s.to("store.opacity", 1.0, 0.4)),
    );
    footer(
        &mut sc,
        "the API never guesses / a slow store becomes a retry, not a wrong answer",
        v.at("client retries"),
    )?;
    Ok(sc.finish()?)
}

// ---------------------------------------------------------------------------
// Reel assembly.
// ---------------------------------------------------------------------------

fn build(narration: &Narration, root: &Path) -> Result<ReelPlan> {
    let plans = [overview(narration)?, request(narration)?];
    let segments = plans
        .into_iter()
        .enumerate()
        .map(|(index, mut plan)| {
            for media in &mut plan.media {
                media.path = root.join(&media.path);
            }
            ReelSegmentPlan {
                transition_nanos: if index == 0 { 0 } else { seconds(0.65) },
                transition_style: ReelTransitionStyle::Dip,
                transition_focus: None,
                transition_wipe: None,
                plan,
            }
        })
        .collect();
    let reel = ReelPlan {
        version: ReelPlan::VERSION,
        id: "{{SLUG}}".into(),
        segments,
    };
    reel.validate()?;
    Ok(reel)
}

fn main() -> Result<()> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let narration = Narration::load(&root.join("narration"))?;
    let reel = build(&narration, root)?;
    fs::write(
        root.join("film.reel.json"),
        serde_json::to_string_pretty(&reel)? + "\n",
    )?;
    println!(
        "{} chapters, {:.2}s",
        reel.segments.len(),
        reel.duration_nanos() as f64 / 1e9
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn film_is_valid_and_deterministic() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let narration = Narration::load(&root.join("narration")).expect("run narrate.mjs first");
        let a = build(&narration, root).unwrap();
        let b = build(&narration, root).unwrap();
        a.validate().unwrap();
        assert_eq!(
            serde_json::to_string(&a).unwrap(),
            serde_json::to_string(&b).unwrap()
        );
        for segment in &a.segments {
            assert_eq!(segment.plan.media.len(), 1);
            assert!(segment.plan.media[0].path.is_file());
        }
    }
}
