---
description: Owner's decision on an escalated PR - posts it and restarts the round count
argument-hint: "<PR number> <decision>"
allowed-tools: ["Bash(gh pr comment:*)", "Bash(gh pr view:*)"]
---

Arguments: $ARGUMENTS - the PR number, then the owner's decision in their words. No decision given: ask for it, never
make one up.

Post on the PR, as one comment:

```
🤖 **Claude Code** (agent, posted from the owner's account):
Owner decided: <decision>; round count restarts.
```

Then say the loop can go on from round 1 (`/codex-review:loop <n>`); do not start it unless the owner asks.
