# Story: how to script an explainer film

Condensed from Kit Langton's `.agents/skills/psychopomp/STORY.md` (full text in the
engine checkout) plus what worked in the CPC/CPA and CPA-caps films.

## Shape of the film

- 4 to 7 chapters, each 15 to 30 seconds of speech. Total 90 to 180 seconds.
- Chapter 1 states the problem or question in the viewer's words. The last chapter
  states what is now true and what did not change.
- One idea per chapter. If a chapter needs two diagrams, it is two chapters.
- Every chapter has a header (`01  short lowercase title`), a chip top-right that
  names the scope (repo, service, ticket), and one footer line that sums up the beat.
- **Behavior before code.** Show the request, the packet, the state change first.
  Show a diff only when the viewer already knows what it fixes.
- **Replay, don't redraw.** Reuse the same actors and positions across chapters.
  When the story changes (before/after, happy path/failure), keep the shared actors
  and change only what differs. The switch is the comparison.

## Choosing actors

| Thing in the system | Stage element |
| --- | --- |
| Person, browser, partner, external client | orb (particle sphere) with a label under it |
| Service, API, module, job | card with title and a status line |
| Database, cache, queue, file store | form (plane that morphs into a box or cylinder) |
| Call, message, event | packet travelling along a beam; reply is a reversed packet |
| Rule, config, invariant | label in Accent tone, shown when spoken |
| Count, budget, latency | RollingNumber chip |
| A note about one element | Callout pinned to it |

Keep 3 to 6 actors on screen. Use the real names: endpoint paths, table names,
env var names, function names. Never invent identifiers.

## Narration text

- Plain, confident, short sentences. Say what happens, then why it matters.
  No hype, no filler, no "basically", no "simply".
- Spell words the way they should be spoken: "two hundred OK", "five oh three",
  "feed twenty seven". Whisper writes digits back; `v.at("twenty seven")` matches "27".
- Write for the ear: "the tracker's cap sync loads them into Redis" not
  "cap sync (jn-feed-tracker) -> Redis".
- The transcript, not the script, decides what an anchor matches. After narrating,
  read `<id>.words.json` before choosing anchors.
- Put words Kokoro mispronounces in `pronounce` with IPA (`"Redis": "/ɹˈɛdɪs/"`).
  Listen to each clip once; fix the IPA, not the spelling.

## Anchors (phrases visuals wait for)

- Plain words, 2 to 4 of them, that appear exactly once in the clip.
- No acronyms (API is fine; TUI, SIGKILL are not), no punctuation, no numerals.
- If a phrase repeats, use `v.at_after("phrase", "earlier phrase")`.
- Beats that prepare a moment (settle a card, draw a wire) go `.early(seconds(0.3..0.6))`
  before the word; the payoff (packet lands, status swaps) goes on the word.
- A reply never launches before `.not_before(request_span.reply())`.

## Facts first

Before writing a single clip, build a facts table: claim, source file, function,
commit. Every sentence in the script must map to one row. That table becomes the
README's "Source checks" section. If the code and the design doc disagree, the film
follows the code and the README says so.

## Scope statements

Say what the film is and is not in chapter 1 and in the README: "explains the
software, not a production audit", "feed 27 and ten dollars are an example".
Define each technical term the first time it is spoken.
