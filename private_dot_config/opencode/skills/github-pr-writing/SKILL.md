---
name: github-pr-writing
description: >
  Formats GitHub pull request titles and descriptions using Jira context,
  including JSD/JPD ticket keys, concise reviewer-focused bodies, and automatic
  Jira comments. Trigger: use when creating, formatting, updating, or reviewing
  GitHub PR titles/descriptions, especially for branches or commits with
  JSD-XXXXX or JPD-XXXXX ticket keys.
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

# GitHub PR Writing

## When to Use

- Creating a GitHub pull request.
- Formatting or improving a PR title or description.
- Updating a PR body after implementation changes.
- Preparing a Jira-linked review summary for `JSD-XXXXX` or `JPD-XXXXX` work.
- Commenting back to Jira with PR-ready review information.

## Critical Rules

- Always look for Jira keys before drafting PR content.
- Jira keys must match `JSD-<digits>` or `JPD-<digits>`.
- If no Jira key is found in the branch name, commits, existing PR text, or user prompt, ask for the ticket key before creating PR text.
- Fetch each Jira ticket with `atlassian_jira_get_issue` before drafting the PR body.
- Include all relevant Jira keys in the PR title when multiple tickets are involved.
- Automatically comment on every related Jira ticket after the PR URL exists.
- Never invent validation. If validation was not run, write `Not run: <reason>`.
- Never invent Jira requirements. If Jira has no clear acceptance criteria, label the requirement as inferred from the ticket summary/description.
- Keep PR bodies concise and reviewer-focused. Prefer under 250 words unless the change is large or risky.
- Put the Jira ticket link near the beginning of the PR body, before the summary, so reviewers can open the source ticket immediately.
- Use screenshots only for UI-visible frontend changes. Otherwise write `Screenshots: Not applicable` only if screenshots would reasonably be expected.

## Title Format

Use this exact pattern:

```text
(<Jira key[, Jira key...]>) <type>: <concise outcome>
```

Allowed types:

```text
feat, fix, refactor, test, docs, chore, perf, build, ci
```

Examples:

```text
(JSD-12345) fix: prevent duplicate webhook processing
(JPD-67890) feat: add checkout retry flow
(JPD-12345, JSD-67890) fix: handle failed payment retries
```

Title guidance:

- Prefer imperative or outcome-based wording.
- Mention the behavior or reviewer-relevant outcome.
- Avoid vague titles like `updates`, `misc fixes`, or `changes`.
- If there are many Jira keys, include all keys only when they are directly addressed by the PR.

## PR Body Template

```markdown
Jira: [<JPD-12345>](<Jira ticket URL>)<, [<JSD-67890>](<Jira ticket URL>)>

## Summary

- <What changed>
- <Why it changed, grounded in Jira context>
- <Important implementation note if useful>

## Jira

- Tickets: [<JPD-12345>](<Jira ticket URL>)<, [<JSD-67890>](<Jira ticket URL>)>
- Type: <Product | Service Desk | Mixed>
- Goal: <short goal from Jira>

## Diagnosis

- <Small statement of the observed problem, root cause, or reason this PR exists>

## Understanding

- <Small statement of the intended behavior or requirement being addressed>

## Plan

- <Small statement of the implementation approach chosen>

## Execution Summary

- <Small statement of what was actually changed>

## Change Map / Requirement Traceability

| Requirement / Acceptance Criteria | Code Change | Reviewer Notes |
| --- | --- | --- |
| <Requirement from Jira, or "Inferred: ..."> | <File/module/function changed> | <Risk, edge case, or rationale> |

## Validation

- [x] <Command or manual check actually performed>
- Not run: <reason, if applicable>

## Reviewer Notes

- <Only include meaningful review guidance, risks, migrations, assumptions, or edge cases>
```

Omit `Reviewer Notes` only if there is genuinely nothing useful to add.
Keep `Diagnosis`, `Understanding`, `Plan`, and `Execution Summary` short: one bullet each by default, grounded in Jira context and the actual diff.

## Change Map / Requirement Traceability

Use this table to connect the requested behavior to the implementation. This helps reviewers verify that each Jira requirement is addressed without reading the entire diff first.

Good entries are specific:

```markdown
| Requirement / Acceptance Criteria | Code Change | Reviewer Notes |
| --- | --- | --- |
| Retry checkout submission after transient payment failure | `payments/retry.py` adds bounded retry handling | Verify retry limit and idempotency behavior |
| Show retry state in checkout UI | `CheckoutRetryBanner.tsx` renders retry status | Confirm copy and disabled button behavior |
```

Avoid generic entries:

```markdown
| Requirement / Acceptance Criteria | Code Change | Reviewer Notes |
| --- | --- | --- |
| Fix bug | Updated code | Looks good |
```

## Jira Comment Template

After creating or updating the PR, automatically comment on each related Jira ticket with the final PR information and link.

```markdown
PR ready for review.

## Summary

- <Same concise summary as PR>

## Change Map / Requirement Traceability

| Requirement / Acceptance Criteria | Code Change | Reviewer Notes |
| --- | --- | --- |
| <Requirement> | <Code Change> | <Notes> |

## Validation

- <Checks actually performed, or Not run: reason>

## PR

<GitHub PR URL>
```

Jira comment rules:

- Comment on every directly related Jira ticket in the PR title/body.
- Do not post the Jira comment until the PR URL is available.
- Keep the Jira comment aligned with the PR body; do not add extra claims.

## Workflow

1. Inspect the branch name and recent commits for Jira keys.
2. Inspect the diff and affected files before drafting the PR.
3. Fetch each Jira ticket with `atlassian_jira_get_issue`.
4. Identify whether the work is Product (`JPD`), Service Desk (`JSD`), or Mixed.
5. Draft the PR title using the required title format.
6. Draft the PR body using Jira context and the actual code changes.
7. Create or update the GitHub PR.
8. After the PR URL exists, add the Jira comment with `atlassian_jira_add_comment` for every related ticket.

## Validation Guidance

Python codebase:

- Prefer targeted `pytest` runs for changed modules.
- Mention linting, type checks, migrations, management commands, API checks, or manual flows when relevant.
- Call out database migrations or operational impact in `Reviewer Notes`.

JavaScript/React frontend projects:

- Prefer targeted tests, build/typecheck, and browser/manual UI checks.
- Include screenshots for visual changes.
- Mention state, loading, error, and accessibility behavior when reviewer-relevant.

## Handling Missing Information

If Jira cannot be fetched:

```markdown
Jira context unavailable: <reason>
```

Then ask whether to proceed without Jira context unless the user explicitly asked for text-only drafting.

If validation was not run:

```markdown
## Validation

- Not run: <reason>
```

If requirements are inferred:

```markdown
| Requirement / Acceptance Criteria | Code Change | Reviewer Notes |
| --- | --- | --- |
| Inferred: <behavior implied by Jira summary/description> | <code change> | <note> |
```

## Commands

Useful commands when preparing a PR:

```bash
git branch --show-current
git log --oneline --decorate -10
git diff --stat
git diff
gh pr create --title "(<Jira key>) <type>: <outcome>" --body "$(cat <<'EOF'
<PR body>
EOF
)"
```
