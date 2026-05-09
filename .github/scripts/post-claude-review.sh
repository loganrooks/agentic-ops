#!/usr/bin/env bash
# post-claude-review.sh — narrow wrapper around `gh pr comment` for the
# Claude PR review workflow.
#
# Why this exists
# ---------------
# The workflow runs with privileged secrets (CLAUDE_CODE_OAUTH_TOKEN,
# GH_TOKEN/GITHUB_TOKEN, runner env). Granting Claude broad access to
# `gh pr comment:*` via --allowedTools opens two attack surfaces against
# untrusted PR-derived content:
#
#   1. File exfiltration via `gh pr comment <pr> --body-file <path>`.
#      Prompt-injected text could direct Claude to post arbitrary files
#      (e.g. /proc/self/environ) into a public PR comment.
#   2. Shell expansion of `--body "<...>"` when the body is synthesized
#      from untrusted PR content (`$(...)`, `$var`, backticks expand
#      before gh sees them).
#
# This wrapper closes both:
#   * Accepts ONE positional argument: the PR number, validated as a
#     non-empty integer. No flags. No file paths. No URLs.
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
# Bash(gh pr comment:*). The trailing :* still lets Claude pass the PR
# number, but the script itself is the only thing that gets to talk to
# gh, and the script's surface is exactly: one integer + stdin.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: post-claude-review.sh <pr-number>

  Reads the PR comment body from stdin and posts it as a single
  top-level comment on the given PR. Pipe via quoted heredoc:

    ./.github/scripts/post-claude-review.sh 42 <<'EOF'
    review body here
    EOF
USAGE
  exit 2
}

if [[ $# -ne 1 ]]; then
  echo "error: expected exactly one argument (PR number), got $#" >&2
  usage
fi

pr="$1"

# Integer-only. No leading +/-, no whitespace, no flags, no paths.
if [[ ! "$pr" =~ ^[0-9]+$ ]]; then
  echo "error: PR number must be a non-negative integer, got: $pr" >&2
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
exec gh pr comment "$pr" --body-file - <<<"$body"
