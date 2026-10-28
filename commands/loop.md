---
description: Run the review loop on a PR until it is ready to merge or stops (review, answer, fix, push; 3 rounds at most)
argument-hint: "<PR number>"
---

Run `/loop /codex-review:pr-review-loop $ARGUMENTS`. No PR number given: use the PR of the current branch
(`gh pr view --json number`); no PR: say so and stop.
