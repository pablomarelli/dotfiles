---
name: code-review-journal
description: "Trigger: GitHub PR review, rereview, reviewpr, Jira ticket. Review PRs against requirements and journal MD/HTML records."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Load this skill when reviewing or rereviewing a GitHub pull request and the user wants durable Markdown and HTML memory of reviewed PRs, Jira requirements, suggested comments, posted comments, or review rounds.

## Hard Rules

- Treat the skill as workflow instructions, not storage. Store review memory in `/Users/pablomarelli/Documents/work-log/wiki`.
- Accept PR input as a GitHub URL, `owner/repo#123`, `owner/repo 123`, or bare `123` when the current directory is inside the target GitHub repo.
- Accept explicit Jira keys anywhere in the user request, including `JSD-123`, `JPD-123`, or any uppercase project key pattern like `ABC-123`.
- Prefer explicit Jira keys from the user over inferred keys from PR metadata, branch names, or commits.
- Review the PR against Jira requirements when Jira keys are available; if Jira cannot be fetched, record that limitation and review against PR context only.
- Never post GitHub comments unless the user explicitly asks to post, submit, approve, or request changes.
- Never invent posted comments. If comments are only drafted, record them as suggested comments.
- For rereviews, compare the current PR head SHA with previous review rounds and avoid repeating resolved feedback.
- Preserve raw captures as immutable source files; update only wiki entity/daily/index/log pages.
- Maintain two synchronized PR entity files: canonical Markdown at `wiki/entities/prs/<slug>.md` and rendered HTML at `wiki/entities/prs/<slug>.html`.
- Treat Markdown as the source of truth. Regenerate the HTML sibling after every PR entity create or update.
- Redact secrets, credentials, private customer data, and irrelevant personal data from journal entries.

## Decision Gates

| Situation | Action |
| --- | --- |
| No PR argument | Ask for a PR URL, `owner/repo#123`, or PR number. |
| Bare PR number outside a GitHub repo | Ask for `owner/repo#number` or URL. |
| Existing PR entity found | Treat as rereview and append a new round. |
| No PR entity found | Treat as first review and create one. |
| Markdown entity exists but HTML sibling is missing | Generate the HTML sibling before returning. |
| Markdown and HTML entity content differ | Update Markdown first, then regenerate HTML from Markdown. |
| User supplied Jira key(s) | Fetch those tickets and use them as the requirements source of truth. |
| No supplied Jira key(s) | Infer from PR title, PR body, branch names, and commit messages. |
| No Jira key found | Review against PR description and diff; record `Jira: not found`. |
| Jira fetch fails | Continue review; record `Jira: unavailable` and the failure reason. |
| User asks to post review | Draft first, then post only after explicit confirmation unless already explicit. |
| Daily page is missing | Create `wiki/daily/YYYY-MM-DD.md` before adding the PR review entry. |

## Execution Steps

1. Resolve the PR reference. Use `gh repo view --json nameWithOwner` for bare numbers, then fetch PR metadata with `gh pr view <ref> --json number,title,body,url,author,state,baseRefName,headRefName,headRefOid,createdAt,updatedAt,additions,deletions,changedFiles,commits,reviews,comments,reviewDecision`.
2. Resolve Jira keys. Extract explicit keys from the user request first, then infer missing keys from PR title, PR body, base/head branch names, and commit messages. Use case-sensitive Jira key pattern `[A-Z][A-Z0-9_]+-[0-9]+`.
3. Fetch each Jira ticket with the available Jira MCP/tooling. Extract summary, status, description, acceptance criteria, comments if relevant, and linked tickets. If Jira is unavailable, continue and record the failure.
4. Capture the diff with `gh pr diff <ref>` and inspect changed files. Load relevant project/language skills before judging code when available.
5. Derive the wiki slug as `<owner>-<repo>-pr-<number>`, lowercase, with non-alphanumeric separators collapsed to hyphens.
6. Look for `/Users/pablomarelli/Documents/work-log/wiki/entities/prs/<slug>.md` and `/Users/pablomarelli/Documents/work-log/wiki/entities/prs/<slug>.html`. If Markdown is present, read prior rounds, prior head SHAs, unresolved feedback, linked Jira keys, and posted comments.
7. Produce review findings using normal code-review priorities plus Jira requirement traceability: correctness, regressions, security, data integrity, tests, maintainability, and whether the PR actually satisfies the ticket requirements. Avoid style-only feedback unless it blocks understanding.
8. Write an immutable raw capture under `wiki/raw/github-pr-reviews/YYYY-MM-DD-<slug>-round-<n>.md` containing metadata, Jira keys and requirement notes, head SHA, changed-file summary, suggested comments, posted comments if known, and source command notes.
9. Create or update `wiki/entities/prs/<slug>.md` with summary, review rounds, Jira requirements, suggested comments, posted comments, rereview notes, unresolved items, related Jira tickets, people, and daily links.
10. Create or update `wiki/entities/prs/<slug>.html` as a rendered sibling of the Markdown entity. Include basic semantic HTML, escaped content, links to the GitHub PR and Jira tickets when available, and a note that the Markdown file is canonical.
11. Create `wiki/daily/YYYY-MM-DD.md` if it does not exist, then add a concise PR review row or work-done bullet with a link to the PR entity and Jira ticket(s).
12. Update `wiki/index.md` for new PR entity pages and append a short maintenance entry to `wiki/log.md`.

## Output Contract

Return:

- PR reviewed and whether it was first review or rereview.
- Jira keys used, whether explicit or inferred, and whether ticket fetch succeeded.
- Review outcome: approve-ready, comments-only, request-changes, or needs-human-decision.
- Requirement coverage summary: covered, partially covered, missing, or unknown.
- Suggested comments, grouped by severity and file/line when available.
- Journal files created or updated, including both `.md` and `.html` PR entity files.
- Any comments posted to GitHub, or `Not posted`.

## References

- `/Users/pablomarelli/Documents/work-log/wiki/SCHEMA.md` — work-log wiki schema and privacy rules.
