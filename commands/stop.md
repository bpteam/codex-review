---
description: Stop the review loop on a PR - posts "Loop stopped" with the open findings and both positions
argument-hint: "<PR number> <why>"
allowed-tools: ["Bash(gh pr comment:*)", "Bash(gh pr view:*)", "Bash(gh api:*)", "Read"]
---

Arguments: $ARGUMENTS - the PR number, then why the loop stops (empty: ask).

Read the PR's last Codex review and the answers after it. Post one comment:

```
🤖 **Claude Code** (agent, posted from the owner's account):
Loop stopped: <why>
```

followed by each open finding (priority, file:line, title) with Codex's position and the author's. End any
`/loop` running on this PR. The Stop hook lets the session finish after this comment.
