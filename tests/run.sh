#!/usr/bin/env bash
# Tests of hooks/review-gate.sh and skills/pr-review-loop/codex-review.sh with fake `gh` and `codex` on PATH.
# Usage: tests/run.sh   (needs bash, git, jq; no network)
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
gate="$here/hooks/review-gate.sh"
review="$here/skills/pr-review-loop/codex-review.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0 failed=0

check() { # name expected actual
  if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else failed=$((failed + 1)); echo "FAIL: $1 (expected $2, got $3)"; fi
}

# Fake gh: answers from files in $FAKE (pr.json, pr.err, comments.json, base).
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view")
    if [[ -f $FAKE/pr.err ]]; then cat "$FAKE/pr.err" >&2; exit 1; fi
    if [[ " $* " == *" baseRefName "* ]]; then cat "$FAKE/base"; exit 0; fi
    if [[ " $* " == *"number,title,body"* ]]; then echo "PR #1: test"; exit 0; fi
    cat "$FAKE/pr.json" ;;
  "api repos/{owner}/{repo}/issues/1/comments") jq -c '.[]' "$FAKE/comments.json" ;;
  *) echo "fake gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
# Fake codex: writes $FAKE/answer.json to the -o file and records the prompt.
cat > "$tmp/bin/codex" <<'EOF'
#!/usr/bin/env bash
out=""; prev=""
for a in "$@"; do [[ $prev == -o ]] && out=$a; prev=$a; done
printf '%s' "${@: -1}" > "$FAKE/prompt.txt"
cp "$FAKE/answer.json" "$out"
EOF
chmod +x "$tmp/bin/gh" "$tmp/bin/codex"
export PATH="$tmp/bin:$PATH" FAKE="$tmp/fake" CODEX_BIN="$tmp/bin/codex"
mkdir -p "$FAKE"

# A repo with an origin, on a feature branch, pushed.
git init -q --bare "$tmp/origin.git"
git init -q -b main "$tmp/repo" && cd "$tmp/repo" || exit 1
git config user.email t@t && git config user.name t
git remote add origin "$tmp/origin.git"
echo a > a && git add a && git commit -qm base && git push -q origin main
git remote set-head origin main
git switch -q -c feature && echo b > b && git add b && git commit -qm change && git push -q origin feature
head=$(git rev-parse HEAD) short=$(git rev-parse --short HEAD)

run_gate() { echo "${1:-{\}}" | "$gate" > /dev/null 2>&1; echo $?; }
pr_open() { echo "{\"number\":1,\"state\":\"OPEN\",\"headRefOid\":\"$head\"}" > "$FAKE/pr.json"; rm -f "$FAKE/pr.err"; }
comments() { jq -n --args '[$ARGS.positional[] | {id: 1, body: .}]' "$@" > "$FAKE/comments.json"; }

# Gate: a repo without review-loop.md is not gated, whatever its PR state.
pr_open; comments
check "no review-loop.md passes" 0 "$(run_gate)"

mkdir -p docs && echo loop > docs/review-loop.md && git add docs && git commit -qm loop && git push -q origin feature
head=$(git rev-parse HEAD) short=$(git rev-parse --short HEAD)
pr_open; comments
check "PR without review blocks" 2 "$(run_gate)"
check "stop_hook_active passes" 0 "$(run_gate '{"stop_hook_active":true}')"
echo "no pull requests found for branch \"feature\"" > "$FAKE/pr.err"
check "no PR passes" 0 "$(run_gate)"
echo "HTTP 502" > "$FAKE/pr.err"
check "gh error blocks" 2 "$(run_gate)"
pr_open
comments "### Codex review (m, high) of $short
**Verdict: approve**. ok"
check "approve passes" 0 "$(run_gate)"
comments "### Codex review (m, high) of $short
**Verdict: needs-attention**. no"
check "needs-attention unanswered blocks" 2 "$(run_gate)"
comments "### Codex review (m, high) of $short
**Verdict: needs-attention**. no" "x
Answers to Codex review of $short:
- reason"
check "needs-attention answered passes" 0 "$(run_gate)"
comments "x
Answers to Codex review of $short:" "### Codex review (m, high) of $short
**Verdict: needs-attention**. no"
check "answer before the review does not count" 2 "$(run_gate)"
mv docs doc && git add -A && git commit -qm doc && git push -q origin feature
head=$(git rev-parse HEAD) short=$(git rev-parse --short HEAD)
pr_open; comments
check "doc/review-loop.md also gates" 2 "$(run_gate)"

# Review script: base from the PR, guidelines from doc/ or docs/, approve with findings becomes needs-attention.
git switch -q main && git switch -q -c release && git push -q origin release && git switch -q feature
echo release > "$FAKE/base"
echo '{"verdict":"approve","summary":"fine","findings":[]}' > "$FAKE/answer.json"
echo rules > doc/review-guidelines.md && git add doc && git commit -qm g && git push -q origin feature
line=$("$review" "$tmp/out/r.md" 2>&1 | tail -1)
check "approve verdict" "verdict: approve" "${line%% (*}"
grep -q 'origin/release\.\.\.HEAD' "$FAKE/prompt.txt"; check "diff against the PR base" 0 $?
grep -q 'Read doc/review-guidelines.md first' "$FAKE/prompt.txt"; check "guidelines from doc/" 0 $?
echo '{"verdict":"approve","summary":"s","findings":[{"priority":"P2","title":"t","file":"a","line_start":1,"line_end":1,"failure":"f","recommendation":"r","confidence":0.5}]}' > "$FAKE/answer.json"
line=$("$review" "$tmp/out/r2.md" 2>&1 | tail -1)
check "approve with findings is needs-attention" "verdict: needs-attention" "${line%% (*}"
echo x > dirty
"$review" "$tmp/out/r3.md" > /dev/null 2>&1; check "dirty tree exits 3" 3 $?

echo "$pass passed, $failed failed"
[[ $failed -eq 0 ]]
