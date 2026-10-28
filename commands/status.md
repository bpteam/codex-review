---
description: Where a PR stands in the review loop - rounds used, last verdict, unanswered findings, Stop hook result
argument-hint: "[PR number] (default: the PR of this branch)"
allowed-tools: ["Bash(gh pr view:*)", "Bash(gh api:*)", "Bash(git rev-parse:*)", "Bash(git fetch:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/hooks/review-gate.sh:*)", "Read"]
---

PR: $ARGUMENTS (empty: the PR of the current branch). Read only: post nothing, change nothing.

From `gh pr view <n> --json headRefOid,isDraft,state,mergeable` and the PR comments
(`gh api repos/{owner}/{repo}/issues/<n>/comments --paginate`), report in a few lines:
- rounds used: `### Codex review (` comments after the last `**Verdict: approve**` review or the last
  `Owner decided: ...; round count restarts.` comment, out of 3;
- the last review: sha, verdict, and whether it is of the current head (same tree);
- findings of the last `needs-attention` review with no `Answers to Codex review of <sha>` comment after it, and any
  `Loop stopped:` comment;
- draft or ready, mergeable or conflicting;
- the Stop hook's answer: `echo '{}' | ${CLAUDE_PLUGIN_ROOT}/hooks/review-gate.sh` (exit 0 passes, 2 blocks, with why);
- the next step: run `/codex-review:loop <n>`, answer the findings, resolve a conflict, or ready to merge.
