# codex-review

A Claude Code plugin for one way of working: Claude writes the code and opens the PR, the local **Codex CLI** reviews
it, Claude fixes or argues every finding until the review is clean (3 rounds at most), and the owner is told once,
when the PR is ready to merge. The owner only merges.

The loop's code lives here, once. A repository that uses the loop keeps only what is its own: `review-guidelines.md`
(what a reviewer checks there), `review-loop.md` (its checks and merge rules), in `doc/` or `docs/`, and a hard rule
in its `AGENTS.md`.

## Contents

| Path | What |
|---|---|
| [`skills/codex-review-setup/`](skills/codex-review-setup/SKILL.md) | sets the loop up in a repository: guidelines, loop doc, `AGENTS.md` rules, a PR that tests it |
| [`skills/pr-review-loop/`](skills/pr-review-loop/SKILL.md) | one round of the loop on a PR; run as `/loop /codex-review:pr-review-loop <number>` |
| [`skills/pr-review-loop/codex-review.sh`](skills/pr-review-loop/codex-review.sh) | runs Codex (`gpt-6-luna`, effort `high`, read-only sandbox, JSON by [`review-output.schema.json`](skills/pr-review-loop/review-output.schema.json)) on the pushed PR head against the PR's base; writes a comment ready to post |
| [`hooks/review-gate.sh`](hooks/review-gate.sh) | Stop hook: a session may not finish while the open PR of its branch has no answered Codex review of its head; passes in a repository without `doc/review-loop.md` or `docs/review-loop.md` |
| [`commands/`](commands/) | the commands below |
| [`tests/run.sh`](tests/run.sh) | tests of the hook and the script with fake `gh` and `codex` |

## Commands

| Command | What |
|---|---|
| `/codex-review:setup` | set the loop up in this repository (skill `codex-review-setup`) |
| `/codex-review:loop [PR]` | run the loop on a PR until it is ready or stops |
| `/codex-review:review [PR]` | one Codex review of the PR head now, posted; no fixes |
| `/codex-review:status [PR]` | rounds used, last verdict, unanswered findings, what the Stop hook says, next step |
| `/codex-review:reset-rounds <PR> <decision>` | the owner's decision on an escalation; the round count restarts |
| `/codex-review:stop <PR> <why>` | stop the loop: `Loop stopped:` with the open findings and both positions |
| `/codex-review:doctor` | can the loop run here: Codex CLI, login, model, `gh`, repo docs, no old copies, not installed twice |
| `/codex-review:activate` | project settings that offer the plugin to every Claude Code user of the repo (needs the plugin on GitHub) |

## Requirements

On the owner's machine: the Codex CLI (shipped with the ChatGPT desktop app at `/usr/lib/chatgpt/resources/codex`,
logged in under `~/.codex`; `CODEX_BIN` overrides), `gh` logged in to the repository's account, `git`, `jq`.
Knobs: `CODEX_REVIEW_MODEL`, `CODEX_REVIEW_EFFORT`, `CODEX_REVIEW_BASE`, `CODEX_REVIEW_TIMEOUT` (header of the script).

## Install

As a plugin (from this checkout, or from GitHub once it is pushed there):

```
/plugin marketplace add ~/p/codex-review
/plugin install codex-review@codex-review
```

Before that, the same files are used from this checkout without the plugin system: `~/.claude/skills/pr-review-loop`
and `~/.claude/skills/codex-review-setup` are symlinks to `skills/*`, and `~/.claude/settings.json` registers
`hooks/review-gate.sh` under `hooks.Stop`. After installing the plugin, remove both symlinks and that hook entry,
or the hook runs twice and the skills show up twice.

Other agents (Codex, a human) run the loop by hand from the repository's `review-loop.md`, with the script at
`skills/pr-review-loop/codex-review.sh` of this checkout.

## Test

```
tests/run.sh
```
