---
description: Check the review loop can run here - Codex CLI, login, model, gh, jq, repo docs, the plugin's Stop hook
argument-hint: "(no arguments)"
allowed-tools: ["Bash(command -v:*)", "Bash(gh auth status:*)", "Bash(jq:*)", "Bash(ls:*)", "Bash(test:*)", "Bash(/usr/lib/chatgpt/resources/codex --version)", "Bash(git rev-parse:*)", "Bash(git remote:*)", "Read"]
---

Check and report each line as OK or the fix. Read only.

1. Codex CLI: `${CODEX_BIN:-/usr/lib/chatgpt/resources/codex}` executable (else `codex` on PATH), its `--version`.
2. Logged in: `~/.codex/auth.json` exists. Model `${CODEX_REVIEW_MODEL:-gpt-6-luna}` is listed in
   `~/.codex/models_cache.json` (`jq -r '.. | objects | select(has("slug")) | .slug'`).
3. `gh` installed and `gh auth status` logged in to the account of this repo's `origin`; `jq` installed.
4. This repository uses the loop: `doc/` or `docs/` has `review-loop.md` and `review-guidelines.md`; `AGENTS.md`
   (or `CLAUDE.md`) has the hard rule "every PR goes through the Codex review loop". Missing: `/codex-review:setup`.
5. No old copy left in the repo: `.claude/skills/pr-review-loop/`, `.claude/hooks/review-gate.sh`, a `gate_review`
   stage in its own Stop hook (they would run twice or drift). Found: say so, offer to remove them in a PR.
6. Not installed twice: no `~/.claude/skills/pr-review-loop` or `~/.claude/skills/codex-review-setup` besides this
   plugin, and no `review-gate.sh` entry in `~/.claude/settings.json`.
