#!/usr/bin/env bash
# Stop hook of the codex-review plugin: the agent may not finish while the open PR of its branch has no Codex review
# of its head. Runs only in a repository that uses the loop (it has doc/review-loop.md or docs/review-loop.md);
# anywhere else it passes. Approved, or needs-attention followed by "Answers to Codex review of <sha>" or
# "Loop stopped:" passes. A branch with a change (or a commit ahead of the default branch) and no PR blocks: work is
# handed over as a PR through the loop, never as "shall I open a PR?". A branch with nothing done and no PR, or no gh
# (the loop cannot run without it): passes; a gh or network error blocks.
# Blocks once (stop_hook_active), never loops. Registered by hooks/hooks.json of the plugin.
set -uo pipefail

if [[ ! -t 0 ]]; then
  HOOK_INPUT="$(timeout 2 cat 2>/dev/null || true)"
  [[ "$(jq -r '.stop_hook_active // false' <<<"$HOOK_INPUT" 2>/dev/null)" == "true" ]] && exit 0
fi
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" || exit 0
LOOP_DOC=""
for d in docs/review-loop.md doc/review-loop.md; do [[ -f $d ]] && { LOOP_DOC=$d; break; }; done
[[ -n $LOOP_DOC ]] || exit 0 # this repository does not use the review loop
DEFAULT="$({ git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true; } | sed 's#^origin/##')"

fail() { # stage project command output_file
  {
    echo "REVIEW GATE: the Codex review loop has not finished on this PR. You may not finish yet."
    echo "This hook blocks once. If the loop cannot run, say so to the owner with this output."
    echo "Command: $3"
    echo "---"
    tail -n 40 "$4"
  } >&2
  exit 2
}

gate_review() { # the Codex review loop ran on the PR head ($LOOP_DOC)
  command -v gh >/dev/null || return 0
  local branch pr num head tree out
  branch="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$branch" == "${DEFAULT:-main}" || "$branch" == HEAD ]] && return 0
  out="$(mktemp)"
  # A gh or network error blocks (the review cannot be confirmed).
  if ! pr="$(gh pr view "$branch" --json number,state,headRefOid 2>"$out")"; then
    if grep -qi 'no pull requests found' "$out"; then
      # Nothing done on the branch (a question answered, an investigation): nothing to hand over. Any status counts,
      # deletions and untracked files too; so does a commit ahead of the default branch.
      if [[ -z "$(git status --porcelain 2>/dev/null)" \
          && -z "$(git log --oneline "origin/${DEFAULT:-main}..HEAD" 2>/dev/null)" ]]; then
        rm -f "$out"; return 0
      fi
      echo "Branch $branch has changes and no PR. Do not ask the owner whether to open one: commit, push, gh pr create, then run the review loop (/loop /codex-review:pr-review-loop <number>; the repo's hard rule \"every PR goes through the Codex review loop\"). Only a question you are truly blocked on stops before that." >"$out"
      fail review . "git commit && git push -u origin HEAD && gh pr create && /loop /codex-review:pr-review-loop <number>" "$out"
    fi
    fail review . "gh pr view $branch" "$out"
  fi
  [[ "$(jq -r .state <<<"$pr")" == OPEN ]] || { rm -f "$out"; return 0; }
  num="$(jq -r .number <<<"$pr")" head="$(jq -r .headRefOid <<<"$pr")"
  if [[ "$(git rev-parse HEAD)" != "$head" ]]; then
    echo "Local HEAD is not the head of PR #$num: push, then run the review loop: /loop /codex-review:pr-review-loop $num (or /loop /pr-review-loop $num without the plugin)." >"$out"
    fail review . "git push && /loop /codex-review:pr-review-loop $num" "$out"
  fi
  tree="$(git rev-parse "$head^{tree}")"
  # Newest review whose commit has the same tree as the PR head (a squash keeps the tree, not the sha).
  local comments verdict sha c
  comments="$(gh api "repos/{owner}/{repo}/issues/$num/comments" --paginate \
    --jq '.[] | {id, body: .body}' 2>"$out")" || fail review . "gh api repos/{owner}/{repo}/issues/$num/comments" "$out"
  verdict="" sha="" at=-1
  local i=0
  while IFS= read -r c; do
    local h s
    h="$(jq -r '.body | split("\n")[0]' <<<"$c")"
    if [[ "$h" =~ ^"### Codex review (".*") of "([0-9a-f]{7,40})$ ]]; then
      s="${BASH_REMATCH[1]}"
      if [[ "$(git rev-parse -q --verify "$s^{tree}" 2>/dev/null)" == "$tree" ]]; then
        sha="$s" at=$i verdict="$(jq -r '.body' <<<"$c" | grep -oE '\*\*Verdict: [a-z-]+\*\*' | head -1)"
      fi
    fi
    i=$((i + 1))
  done < <(jq -c '.' <<<"$comments")
  if [[ -z "$sha" ]]; then
    echo "PR #$num head ${head:0:7} has no Codex review. Run the review loop before finishing (AGENTS.md hard rule)." >"$out"
    fail review . "/loop /codex-review:pr-review-loop $num (or /loop /pr-review-loop $num without the plugin)" "$out"
  fi
  [[ "$verdict" == "**Verdict: approve**" ]] && { rm -f "$out"; return 0; }
  # needs-attention: every finding answered (soft rule), or the loop stopped and told the owner. Only comments posted
  # after this review count: an answer or an escalation of an earlier round says nothing about this one.
  if jq -s -r --argjson at "$at" '.[$at + 1:][] | .body' <<<"$comments" \
      | grep -qE "^(Answers to Codex review of $sha|Loop stopped:)"; then
    rm -f "$out"; return 0
  fi
  echo "Codex review of $sha on PR #$num is needs-attention and no 'Answers to Codex review of $sha' comment exists. Fix or answer every finding ($LOOP_DOC)." >"$out"
  fail review . "/loop /codex-review:pr-review-loop $num (or /loop /pr-review-loop $num without the plugin)" "$out"
}

gate_review
exit 0
