---
description: Make this repository ask every Claude Code user to install the plugin (project settings), so the gate is never missing
argument-hint: "(no arguments)"
allowed-tools: ["Read", "Edit", "Write", "Bash(jq:*)", "Bash(git remote:*)"]
---

Adds to the project's `.claude/settings.json` (create it if missing; keep every other key and hook):

```json
{
  "extraKnownMarketplaces": {
    "codex-review": { "source": { "source": "github", "repo": "<owner>/codex-review" } }
  },
  "enabledPlugins": { "codex-review@codex-review": true }
}
```

Claude Code then offers the plugin to anyone who trusts the repository. Ask for the GitHub repo of the plugin if it
is not known; the plugin must be on GitHub (a local path works only on the owner's machine). Show the change before
writing it, then commit it through the repo's usual PR (which goes through the loop).
