#!/usr/bin/env bash
# post-claude-review.sh — narrow wrapper around `gh pr comment` /
# `gh issue comment` for the Claude review workflow.
#
# Why this exists
# ---------------
# The workflow runs with privileged secrets (CLAUDE_CODE_OAUTH_TOKEN,
# GH_TOKEN/GITHUB_TOKEN, runner env). Granting Claude broad access to
# `gh pr comment:*` or `gh issue comment:*` via --allowedTools opens two
# attack surfaces against untrusted PR- or issue-derived content:
#
#   1. File exfiltration via `gh pr comment <pr> --body-file <path>`.
#      Prompt-injected text could direct Claude to post arbitrary files
#      (e.g. /proc/self/environ) into a public PR comment.
#   2. Shell expansion of `--body "<...>"` when the body is synthesized
#      from untrusted PR content (`$(...)`, `$var`, backticks expand
#      before gh sees them).
#
# This wrapper closes both:
#   * Accepts one required positional argument: the PR/issue number,
#     validated as a non-empty integer. Accepts one optional fixed enum:
#     `pr` (default) or `issue`. No flags. No file paths. No URLs.
#   * Reads the comment body from STDIN ONLY and forwards it to gh via
#     `--body-file -`. Callers must pipe via a quoted heredoc
#     (`<<'EOF'`) so that bash itself does not expand the body before
#     it reaches this script.
#   * Refuses extra arguments. There is no surface for `--body-file`,
#     `--body`, `--edit-last`, or any other gh flag.
#
# Hardening discipline
# --------------------
# Allowlist Bash(./.github/scripts/post-claude-review.sh:*) instead of
# Bash(gh pr comment:*) / Bash(gh issue comment:*). The trailing :*
# still lets Claude pass the numeric target and optional fixed surface,
# but the script itself is the only thing that gets to talk to gh, and
# the script's surface is exactly: one integer + optional enum + stdin.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: post-claude-review.sh <number> [pr|issue]

  Reads the comment body from stdin and posts it as a single top-level
  comment on the given PR (default) or issue. Pipe via quoted heredoc:

    ./.github/scripts/post-claude-review.sh 42 pr <<'EOF'
    review body here
    EOF
USAGE
  exit 2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "error: expected one or two arguments (number plus optional pr|issue), got $#" >&2
  usage
fi

number="$1"
surface="${2:-pr}"

# Integer-only. No leading +/-, no whitespace, no flags, no paths.
if [[ ! "$number" =~ ^[0-9]+$ ]]; then
  echo "error: target number must be a non-negative integer, got: $number" >&2
  exit 2
fi

if [[ "$surface" != "pr" && "$surface" != "issue" ]]; then
  echo "error: target surface must be 'pr' or 'issue', got: $surface" >&2
  exit 2
fi

# Refuse a fully-empty body — likely a bug in the caller, not a real
# review. Read all of stdin first so we can guard the empty case before
# spending an API call.
body="$(cat)"
if [[ -z "${body//[[:space:]]/}" ]]; then
  echo "error: refusing to post an empty comment body (stdin was empty or whitespace-only)" >&2
  exit 2
fi

# --body-file - reads from stdin, so re-feed the body we just consumed.
# Using exec is intentional: this script has no work to do after the
# gh call, and exec gives gh's exit status directly to the caller.
case "$surface" in
  pr)
    exec gh pr comment "$number" --body-file - <<<"$body"
    ;;
  issue)
    exec gh issue comment "$number" --body-file - <<<"$body"
    ;;
esac
