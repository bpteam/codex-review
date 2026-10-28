---
name: codex-review-setup
description: Set up the Codex review loop in a repository - Claude opens PRs, the local Codex CLI (gpt-6-luna, reasoning high) reviews them, Claude fixes or argues every finding until the review is clean, the owner is pinged only when the PR is ready to merge. Use when the owner says to work "through code review with Codex" in a repo, or asks to set this loop up. Also covers running the loop once it is set up.
---

# Codex review loop: setup in a repository

Goal: the owner only merges. Claude writes the code and opens the PR; Codex reviews it locally; Claude answers every
finding (fix with a test, or a reason why not) until Codex says `approve` (3 rounds at most); then the owner gets one notice.
The loop's code is shared, not copied into repositories: this plugin (`codex-review`) holds the round skill
`pr-review-loop` with `codex-review.sh` and its schema, and the Stop hook `hooks/review-gate.sh`. A repository keeps
only what is its own: `review-guidelines.md`, `review-loop.md` (in `doc/` or `docs/`, whichever it uses) and the
rules in its `AGENTS.md`. Reference: repos `Noitadnuof/reviva` (`doc/`) and `bpteam/prosopon` (`docs/`).

## Facts that shaped it (do not rediscover)

- The Codex GitHub app (`@codex review`, bot `chatgpt-codex-connector[bot]`) has no model choice and needs a Codex
  cloud environment of the repo. The loop does not use it. If it reviews anyway, its inline comments are findings
  like any other: answer in the thread, resolve the ones fixed.
- Codex CLI ships with the ChatGPT desktop app: `/usr/lib/chatgpt/resources/codex`, login in `~/.codex`. Model ids:
  `jq -r '.. | objects | select(has("slug")) | .slug' ~/.codex/models_cache.json`. `gpt-6-luna` efforts:
  low, medium, high, xhigh, max. `high` (about 1 minute) is the default: `low` misses real bugs, `max` takes about
  5 minutes and 230k tokens for a small diff.
- `codex review --base` refuses a custom prompt, so the script uses `codex exec -s read-only --output-schema
  review-output.schema.json -o <file>.json`: a verdict (`approve` / `needs-attention`) and findings with priority,
  file, lines, failure, fix, confidence. No parsing of free text.
- Taken from OpenAI's `openai/codex-plugin-cc`: the adversarial stance ("find reasons not to merge"), the attack
  surface list, the finding bar (what fails, why, impact, fix; inferences marked; one strong finding over several
  weak), the output schema, a 15-minute timeout. Not taken: its "ask the user before fixing anything" rule and its
  Stop-hook gate on every turn (unbounded, drains limits). The plugin itself is not needed.
- PRs are opened from the owner's GitHub account: GitHub refuses a review request to the author, so the "ready"
  signal is `gh pr ready` plus a push notification, not a reviewer request.

## Setup steps

Work in a worktree and a branch like any change; follow the repo's own rules for docs, checks and PRs.

1. Read the repo's `AGENTS.md` / `CLAUDE.md` and docs index. Collect its hard rules: what a reviewer must check
   here (data model rules, security and tenant isolation, API compatibility, migrations, docs following code, ...).
2. `review-guidelines.md` in `doc/` or `docs/` (the script reads it from there): what the reviewer checks, for this repo.
   - How to review: PR description first, then diff and surrounding code; a finding names file:line, a concrete
     failure scenario and the fix; no finding without a failure; read nested `AGENTS.md` of touched projects;
     skip what linters and type checks catch; nothing to report = say so, no filler nits.
   - Priorities: P0 (data loss, security, cross-tenant access, secrets, broken running release), P1 (a hard rule
     broken, a real bug, a breaking API change, silent failure), P2 (missing test, stale docs, rare-path bug).
   - Hard rules to check: one bullet per rule of the repo, each pointing to where the rule is written. Link, do not
     copy the rule text.
3. `AGENTS.md` (or `CLAUDE.md` when there is no `AGENTS.md`), so every agent in the repo uses the loop on its own:
   - a hard-rule section, in the style of the file's other hard rules:
     `## ⛔ HARD RULE: every PR goes through the Codex review loop; the owner only merges` - after opening a PR the
     author agent runs the loop every time without being asked (Claude Code: `/loop /pr-review-loop <number>`,
     other agents: the repo's `review-loop.md` by hand); review, post, fix or argue every finding, push, again until
     `approve` or every finding left is answered with a reason, at most 3 rounds; then `gh pr ready` and one notice
     listing the findings left open; the owner is not asked to look before that, except when the
     loop stops on its own rules;
   - a short `## Review guidelines` section that only points to the file ("Reviewing a pull request (Codex or any
     agent): read <doc or docs>/review-guidelines.md first and follow it");
   - every nested `AGENTS.md` / `CLAUDE.md` of sub-projects: one line linking to that root section.
4. Nothing to copy: the round skill and `codex-review.sh` come from this plugin. Check they are installed: the
   `pr-review-loop` skill is listed (plugin: `codex-review:pr-review-loop`) and `codex-review.sh` sits in its
   directory. Not installed: tell the owner (`README.md` of the plugin, *Install*) and stop. If the repo still has
   an old copy (`.claude/skills/pr-review-loop/`, `.claude/hooks/review-gate.sh`, a `gate_review` stage in its own
   Stop hook), remove it in this change.
5. `review-loop.md` (in `doc/` or `docs/`; the Stop hook only runs in a repo that has it): roles (author agent,
   Codex CLI, owner), the steps and the stop table below, where this repo's checks and merge rules are, why local
   CLI and not the GitHub app, that the CLI and the loop's code are tools of the owner's machine (like `gh`), not of
   the project, and how another agent runs the script by hand (its path in the installed plugin or skill).
6. Add the `pr-review-loop` skill to the repo's skills index, if it has one, as an external skill of this plugin.
7. Stop hook: none to install. The plugin registers `hooks/review-gate.sh` for every session; it passes in a repo
   without `review-loop.md`. The repo's own Stop hook stays as it is (the review is not one of its stages).
   It passes on `approve`, or on `needs-attention` followed by a later `Answers to Codex review of <sha>` or
   `Loop stopped:` comment; it matches reviews by tree, so a squash keeps the review; no PR, or no `gh`, passes;
   a `gh` error blocks; it blocks once. It is a reminder, not a security boundary: the loop posts from the owner's
   account.
8. Docs index lines for both new docs. Run the repo's checks.
9. Open the PR and run the loop on that PR itself: it is the test of the setup (the Stop hook must block before
   the first review and pass after it).

## The loop

One round per call: [`../pr-review-loop/SKILL.md`](../pr-review-loop/SKILL.md). Running the loop on a PR
means `/loop /pr-review-loop <number>` (plugin: `/loop /codex-review:pr-review-loop <number>`).

## Stop table (for the repo's `review-loop.md`)

| State | Then |
|---|---|
| `verdict: approve` on the last pushed commit, checks green | `gh pr ready`, push notification "PR #n ready to merge" |
| only findings the author disagrees with, each answered | same; the notice names them so the owner decides |
| 3 rounds since the last `approve` or owner's answer (never a 4th) with a finding unanswered, or a product decision | stop, notify the owner with open findings and both positions |
| `codex-review.sh` fails twice | stop, notify the owner with its error |

Before merge, follow the repo's merge rules (e.g. squash into one commit); if the squash changes the tree, run one
more round on the new head.

The PR conflicts with its base (or the owner says "merge"): merge `origin/<base>` into the branch yourself and
resolve the conflicts; if the app's `sync_with_base_branch` refuses, use a plain `git merge` in the worktree at
once, do not retry it or send the owner to app settings. Then checks, push, one more round on the new head.

After the owner answers an escalation in the PR, the author posts `Owner decided: <decision>; round count restarts.`
and the loop goes on from round 1.
