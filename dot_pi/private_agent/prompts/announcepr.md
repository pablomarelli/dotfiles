---
description: Announce your latest PR to eng-vle, or a supplied Slack channel
argument-hint: "[Slack channel]"
---

Load and follow the `prnotify-announcement` skill. In the active repository, send a Slack announcement for the most recently created pull request authored by the current GitHub user. Send it to `${1:-eng-vle}`. This is an explicit request to post, so do not preview or request confirmation. Report the PR number, URL, and destination after sending.
