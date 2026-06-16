---
description: Review a GitHub PR against Jira requirements and journal MD/HTML records
---

Read the skill file at ~/.config/opencode/skills/code-review-journal/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: !`echo -n "$(pwd)"`
- Current branch: !`git branch --show-current 2>/dev/null || true`
- Current GitHub repo: !`gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true`
- User request: $ARGUMENTS

TASK:
Review the GitHub pull request specified by `$ARGUMENTS` and journal the review into `/Users/pablomarelli/Documents/work-log/wiki` with synchronized Markdown and HTML PR entity records.

INPUT FORMAT:
Accept a GitHub PR URL, `owner/repo#123`, `owner/repo 123`, or bare `123` when `Current GitHub repo` is available.

JIRA INPUT:
Accept Jira ticket keys anywhere in `$ARGUMENTS`, such as `JSD-12345`, `JPD-67890`, or `ABC-123`. If Jira keys are provided, treat them as the requirements source of truth. If none are provided, infer Jira keys from the PR title, PR body, branch names, and commits.

EXAMPLES:
- `/reviewpr https://github.com/owner/repo/pull/123 JPD-456`
- `/reviewpr owner/repo#123 JSD-123 JPD-456`
- `/reviewpr 123`

DEFAULT BEHAVIOR:
Fetch Jira requirements when keys are available, draft suggested review comments, and update the journal. For PR entity records, update the canonical `.md` file and regenerate the sibling `.html` file. Do not post comments, approve, or request changes on GitHub unless `$ARGUMENTS` explicitly asks to post, submit, approve, or request changes.
