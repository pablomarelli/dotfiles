---
description: Write or update a GitHub PR using Jira-aware PR formatting
---

Read the skill file at ~/.config/opencode/skills/github-pr-writing/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: !`echo -n "$(pwd)"`
- Current branch: !`git branch --show-current 2>/dev/null || true`
- User request: $ARGUMENTS

TASK:
Prepare GitHub pull request content for the current branch using the github-pr-writing workflow.

If `$ARGUMENTS` asks to create or update the PR, do that. Otherwise, inspect the branch, commits, diff, and Jira context, then draft the PR title and body for review.
