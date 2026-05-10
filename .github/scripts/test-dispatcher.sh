#!/usr/bin/env bash
# test-dispatcher.sh — smoke test for the mode dispatcher logic in
# .github/workflows/review.yml.
#
# This script re-implements the dispatcher's case statement and asserts
# expected outputs for a fixture set of trigger comments. KEEP IN SYNC
# with the case block in review.yml — when review.yml gains a new mode,
# this file must too. CI runs this on every PR.
#
# Run:  bash .github/scripts/test-dispatcher.sh
# Exit: 0 if all tests pass; 1 with a FAIL line on first mismatch.

set -euo pipefail

# ----- Dispatcher (mirror of review.yml) -----
# When review.yml's case statement changes, mirror the change here.
dispatch() {
  local body="$1"
  local cmd
  # First non-empty line, leading/trailing whitespace stripped — same
  # extraction logic as review.yml's awk pipeline.
  cmd="$(printf '%s\n' "$body" | awk 'NF { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }')"
  case "$cmd" in
    "@claude opus"|"@claude opus "*)     echo "opus";   return 0 ;;
    "@claude deep"|"@claude deep "*)     echo "deep";   return 0 ;;
    "@claude quick"|"@claude quick "*)   echo "quick";  return 0 ;;
    "@claude gates"|"@claude gates "*)   echo "gates";  return 0 ;;
    "@claude review"|"@claude review "*) echo "review"; return 0 ;;
    "@claude survey"|"@claude survey "*) echo "survey"; return 0 ;;
    *) return 1 ;;
  esac
}

# ----- Test harness -----
# assert <name> <expected-mode-or-empty> <body>
# Empty <expected-mode> means the dispatcher MUST reject (exit 1).
assert() {
  local name="$1" expected="$2" body="$3"
  local actual rc
  if actual="$(dispatch "$body" 2>/dev/null)"; then
    rc=0
  else
    rc=$?
    actual=""
  fi
  if [[ -n "$expected" ]]; then
    if [[ "$actual" == "$expected" && $rc -eq 0 ]]; then
      echo "PASS: $name"
    else
      echo "FAIL: $name — expected=[$expected] actual=[$actual] rc=$rc" >&2
      exit 1
    fi
  else
    if [[ $rc -ne 0 ]]; then
      echo "PASS: $name (rejected as expected)"
    else
      echo "FAIL: $name — expected rejection, got mode=[$actual]" >&2
      exit 1
    fi
  fi
}

# ----- Positive cases (each currently-supported mode, bare + with text) -----
assert "review bare"          "review" "@claude review"
assert "review with text"     "review" "@claude review please look at auth"
assert "quick bare"           "quick"  "@claude quick"
assert "quick with text"      "quick"  "@claude quick scan for AI failure modes"
assert "deep bare"            "deep"   "@claude deep"
assert "deep with text"       "deep"   "@claude deep look at the schema diff"
assert "gates bare"           "gates"  "@claude gates"
assert "gates with text"      "gates"  "@claude gates check the new fallback branches"
assert "opus bare"            "opus"   "@claude opus"
assert "opus with text"       "opus"   "@claude opus check cli vs config"
assert "survey bare"          "survey" "@claude survey"
assert "survey with text"     "survey" "@claude survey map this large PR"

# ----- Word-boundary cases (must reject prefix-only matches) -----
assert "reviewing prefix"     ""       "@claude reviewing my code"
assert "gatesomething prefix" ""       "@claude gatesomething"
assert "deeper prefix"        ""       "@claude deeper"
assert "opuscar prefix"       ""       "@claude opuscar"
assert "quickly prefix"       ""       "@claude quickly look"

# ----- Other negative cases -----
assert "no @claude"           ""       "please review this"
assert "@claude alone"        ""       "@claude"
assert "incidental mention"   ""       "did anyone try @claude review?"
assert "empty body"           ""       ""
assert "whitespace body"      ""       "   "

# ----- First-non-empty-line discipline -----
# Leading blank lines are ignored; the trigger must be on the first
# non-empty line.
assert "leading blank lines"  "review" $'\n\n@claude review\nnotes below'
assert "trigger after text"   ""       $'some prose\n@claude review'

echo "All dispatcher tests passed."
