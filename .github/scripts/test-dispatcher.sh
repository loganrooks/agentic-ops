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
dispatch_full() {
  local body="$1"
  local cmd mode model audit_target
  # First non-empty line, leading/trailing whitespace stripped — same
  # extraction logic as review.yml's awk pipeline.
  cmd="$(printf '%s\n' "$body" | awk 'NF { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }')"
  audit_target=""
  case "$cmd" in
    "@claude opus"|"@claude opus "*)     mode=opus;   model=claude-opus-4-7   ;;
    "@claude deep"|"@claude deep "*)     mode=deep;   model=claude-sonnet-4-6 ;;
    "@claude quick"|"@claude quick "*)   mode=quick;  model=claude-sonnet-4-6 ;;
    "@claude gates"|"@claude gates "*)   mode=gates;  model=claude-sonnet-4-6 ;;
    "@claude review"|"@claude review "*) mode=review; model=claude-sonnet-4-6 ;;
    "@claude survey"|"@claude survey "*) mode=survey; model=claude-sonnet-4-6 ;;
    "@claude audit"|"@claude audit "*|"@claude audit:"*)
      mode=audit
      model=claude-sonnet-4-6
      audit_target="$(printf '%s' "$cmd" | sed -E 's/^@claude audit:?[[:space:]]*//')"
      ;;
    *) return 1 ;;
  esac
  printf 'mode=%s\nmodel=%s\naudit_target=%s\n' "$mode" "$model" "$audit_target"
}

dispatch() {
  local body="$1"
  dispatch_full "$body" | sed -n 's/^mode=//p'
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

# assert_full <name> <expected-mode> <expected-model> <expected-audit-target> <body>
assert_full() {
  local name="$1" expected_mode="$2" expected_model="$3" expected_target="$4" body="$5"
  local output actual_mode actual_model actual_target
  if ! output="$(dispatch_full "$body" 2>/dev/null)"; then
    echo "FAIL: $name — dispatcher rejected body" >&2
    exit 1
  fi
  actual_mode="$(printf '%s\n' "$output" | sed -n 's/^mode=//p')"
  actual_model="$(printf '%s\n' "$output" | sed -n 's/^model=//p')"
  actual_target="$(printf '%s\n' "$output" | sed -n 's/^audit_target=//p')"
  if [[ "$actual_mode" == "$expected_mode" && "$actual_model" == "$expected_model" && "$actual_target" == "$expected_target" ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name — expected=[$expected_mode|$expected_model|$expected_target] actual=[$actual_mode|$actual_model|$actual_target]" >&2
    exit 1
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
assert "audit bare"           "audit"  "@claude audit"
assert "audit lens"           "audit"  "@claude audit:agential-dx"
assert "audit free-form"      "audit"  "@claude audit Are we ready?"

# ----- Audit output cases (mode + model + audit_target) -----
assert_full "audit bare outputs"      "audit" "claude-sonnet-4-6" ""              "@claude audit"
assert_full "audit lens outputs"      "audit" "claude-sonnet-4-6" "agential-dx"   "@claude audit:agential-dx"
assert_full "audit free-form outputs" "audit" "claude-sonnet-4-6" "Are we ready?" "@claude audit Are we ready?"

# ----- Word-boundary cases (must reject prefix-only matches) -----
assert "reviewing prefix"     ""       "@claude reviewing my code"
assert "gatesomething prefix" ""       "@claude gatesomething"
assert "deeper prefix"        ""       "@claude deeper"
assert "opuscar prefix"       ""       "@claude opuscar"
assert "quickly prefix"       ""       "@claude quickly look"
assert "surveying prefix"     ""       "@claude surveying this PR"
assert "auditing prefix"      ""       "@claude auditing the repo"

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
