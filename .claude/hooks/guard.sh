#!/usr/bin/env bash
# PreToolUse(Bash) guard: deny git commands that discard uncommitted work.
# exit 2 blocks the call and feeds stderr back to the agent.
# Self-check: bash .claude/hooks/guard.sh --self-test

# ponytail: matches a git verb in command position (line start or after a
# separator), so prose that merely names one — a commit message, a doc — passes.
blocked() {
  grep -Eq '(^|[;&|(]|&&|\|\|)[[:space:]]*(sudo[[:space:]]+)?git[[:space:]]+(reset[^|;&]*--hard|checkout[^|;&]*[[:space:]]--([[:space:]]|$)|clean[^|;&]*[[:space:]]-{1,2}[a-zA-Z]*f)' <<<"$1"
}

if [ "$1" = --self-test ]; then
  deny=(
    'git reset --hard'
    'git reset HEAD~1 --hard'
    'git checkout -- .'
    'git checkout -- lib/main.dart'
    'git clean -fd'
    'git clean -df'
    'git clean --force'
    'cd /tmp && git reset --hard'
  )
  allow=(
    'git status'
    'git clean -n'
    'git checkout main'
    'git reset HEAD lib/main.dart'
    'git diff -- lib'
    'flutter test'
    'echo "the hook denies git reset --hard and git clean -fd"'
  )
  for c in "${deny[@]}"; do
    blocked "$c" || { echo "FAIL, should block: $c"; exit 1; }
  done
  for c in "${allow[@]}"; do
    blocked "$c" && { echo "FAIL, should allow: $c"; exit 1; }
  done
  echo "self-test ok"
  exit 0
fi

cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')
if blocked "$cmd"; then
  echo "Blocked: this discards uncommitted work. Ask the user to run it themselves." >&2
  exit 2
fi
