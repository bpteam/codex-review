---
description: One Codex review of a PR head now, posted on the PR (no fixes, no loop)
argument-hint: "[PR number] (default: the PR of this branch)"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/skills/pr-review-loop/codex-review.sh:*)", "Bash(gh pr view:*)", "Bash(gh pr comment:*)", "Bash(git status:*)", "Bash(git rev-parse:*)", "Read"]
---

PR: $ARGUMENTS (empty: `gh pr view --json number` of the current branch; no PR: say so and stop).

1. In the PR's worktree, the tree clean and HEAD pushed (`${CLAUDE_PLUGIN_ROOT}/skills/pr-review-loop/codex-review.sh` refuses otherwise: report its error, do not commit or push on your own).
2. Run `${CLAUDE_PLUGIN_ROOT}/skills/pr-review-loop/codex-review.sh <scratchpad>/codex-review-<n>-manual.md` in the background (about a minute).
3. Post the Markdown file as is: `gh pr comment <n> --body-file <file>`.
4. Report the verdict and each finding in one line (priority, file:line, title). Do not fix anything: that is `/codex-review:loop`.
