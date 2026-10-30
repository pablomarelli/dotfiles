---
name: launch-qa
description: Run five first-time-user browser journeys, rank launch friction by affected users, fix findings, and rerun all five journeys with evidence.
disable-model-invocation: true
---

# Launch QA

Act as the user's launch QA lead. Run five first-time-user subagents in real browsers, merge their findings by affected-user count, fix the findings in one coordinated pass, then rerun all five users to verify the fixes.

## 1. Establish the target

Read the project's agent instructions and identify the app URL, source repository, startup procedure, and safe test environment. Use supplied context first. Ask for missing access or an ambiguous target before testing.

Define "first success" as a concrete user-visible result of the app's core purpose, not merely signing up, unless signup itself is the product's goal. Record the starting URL and success criterion so both rounds test the same journey.

Use disposable accounts and synthetic data. Confirm permission before testing against production or triggering charges, real messages, destructive actions, or external side effects. Keep breaker inputs bounded to ordinary UI robustness testing. Do not fabricate pricing, legal promises, or privacy policies to resolve missing content; flag decisions that need the owner.

Create a run directory using the project's artifact convention, or an approved temporary directory if none exists. Keep separate `before/` and `after/` evidence for each persona, plus one merged report. Keep credentials and personal data out of screenshots and reports.

Proceed when the target, first-success criterion, browser access, safe test boundaries, and evidence destination are known.

## 2. Run the five users

Spawn exactly five `general` subagents, one per persona below. These are simulated first-time users, not human research participants. Give each the target, success criterion, safe test boundaries, evidence directory, browser-isolation instructions, persona, and reporting contract from this skill. Make the prompt self-contained.

| Persona | Behavior |
| --- | --- |
| Impatient | Skim, click the first plausible button, and quit at the first error. Capture the abandonment point rather than recovering like an engineer. |
| Skeptic | Read pricing, terms, and privacy before signing up. Note missing information, contradictions, unclear commitments, and trust blockers. |
| Mobile | Do everything in a 375 CSS-pixel-wide viewport with slow 3G. Check navigation, forms, keyboards where supported, loading feedback, and horizontal overflow. |
| Non-native English speaker | Follow only what the UI literally says. Do not fill gaps using idioms, domain expertise, hidden conventions, or knowledge of the implementation. |
| Breaker | Paste junk into forms, navigate back mid-flow, and double-click actions. Probe validation, state recovery, and duplicate submissions within the approved test boundaries. |

Run independent journeys in parallel only when each agent has its own browser context or isolated browser process, account, storage, and test records. Separate tabs sharing cookies are not sufficient isolation. Shared browser tools can also race on active-page selection, viewport, or throttling. If isolation is unavailable, serialize the five agents' browser access and explain the limitation. Keep five distinct agents rather than substituting one agent playing every role.

For mobile, enable actual browser network throttling, not sleeps. Prefer a supported Slow 3G preset; otherwise set and record explicit latency, download, and upload limits. Record viewport height and whether touch/mobile emulation is enabled. If throttling is unavailable, report that coverage as blocked rather than claiming slow-3G testing.

### Subagent contract

- Open the landing page in a real browser with clean user state and attempt the journey to first success. Persona-driven abandonment is a valid observed outcome.
- Discover the flow through the UI. Do not inspect source code, consult other personas' findings, or repair the app during this round.
- Screenshot every moment of confusion, blockage, or annoyance as it happens, before navigating away or recovering. Save a screenshot of first success or abandonment too.
- For each finding, return persona, concise title, URL and step, exact actions and inputs, expected behavior, observed behavior, user impact, and screenshot paths. Quote unclear UI text verbatim. Separate observed failures from subjective friction.
- Return the full attempted journey, whether first success was reached, abandonment reason if any, browser settings, and any inaccessible or untested steps. Attach relevant console or network errors when available, without treating them as a substitute for visible evidence.
- If tools or access fail, report the blocker. Do not invent browser observations, screenshots, or successful outcomes.

Finish the discovery round only when all five agents have returned either evidence-backed results or explicit blockers. Keep the app unchanged until all five finish so they test the same version.

## 3. Merge and rank

Deduplicate findings that describe the same user-visible problem. Keep separate problems separate even when they may share a root cause. Assign stable finding IDs and link every affected persona's evidence.

Rank primarily by distinct affected personas, descending, with a maximum of 5/5. Multiple incidents from one persona count once. Break ties by impact, prioritizing blocked first success, data loss, duplicate side effects, then other friction. Flag critical security or data-loss findings immediately even if only one persona encounters them.

Use this table in the merged report:

| Rank | ID | Finding | Affected personas | Count / 5 | Impact | Before evidence | Fix or blocker | After evidence | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

Mark untested exposure separately. A persona who never reached a step did not prove that step works. Count actual observations, not guessed reach or population-level prevalence.

Proceed when every reported problem is represented in the merged list and its count can be traced to persona evidence.

## 4. Fix in one coordinated pass

Reproduce findings from their browser steps, inspect the implementation, and fix all actionable findings before beginning the verification round. Coordinate shared root-cause fixes in the parent agent rather than letting the five users edit competing files.

Follow repository conventions, preserve unrelated user changes, add regression tests appropriate to the behavior, and run relevant lint, type checks, and tests. For copy or layout friction, fix the observed misunderstanding or interaction problem, not just the console error. Check the rendered result at the affected viewport.

If a finding needs credentials, product policy, approval, or an unavailable external service, record the blocker and the decision needed. Do not silently drop it or describe it as fixed. "One pass" means a coordinated repair batch, not permission to stop with known failures.

Proceed when each finding has an implemented fix with checks or an explicit blocker, and the running app serves the updated code.

## 5. Rerun all five users

Spawn five fresh subagents with the same personas and reporting contract. Give them clean browser state and new disposable accounts or reset test fixtures. Keep the starting URL, success criterion, viewport, and network settings consistent with the discovery round.

Have them attempt landing page to first success without disclosing previous findings first, preserving the first-time-user test. After each independent journey, ask that agent to replay the specific original failure steps relevant to its persona and capture the result. Label this second part as regression verification, not fresh-user discovery.

Match after-evidence to every original finding ID and record new issues separately. A finding is verified only when the original failure steps now produce the expected user-visible result. Tests passing or a different happy path do not prove the finding is fixed.

If a rerun still fails, repair the remaining issues and repeat the affected regression checks. If changes affect shared journey behavior, rerun all five journeys again. Keep unresolved and blocked items visible; do not claim a clean launch while they remain.

## Deliverable

Return the report path, ranked findings with before/after evidence, fixes made, checks run, and each persona's initial and final journey outcome. State remaining blockers and coverage gaps. Only claim verification for behavior observed in the rerun. Distinguish a clean simulated QA run from proof that real users will have no problems.
