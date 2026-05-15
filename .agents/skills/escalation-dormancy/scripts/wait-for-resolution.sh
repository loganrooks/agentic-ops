#!/usr/bin/env bash
# wait-for-resolution.sh
#
# Block until an escalation file gets a `RESOLVED:` or `BLOCKED:` line at
# column 0. Used by the Codex /goal agent during DORMANT state per the
# escalation dormancy contract (see .planning/EXECUTION-MODEL.md).
#
# Token cost: ZERO while blocking. The agent is in a single foreground
# bash tool invocation; no model inference happens until this script
# returns.
#
# Wake mechanism: prefers `fswatch -1` (FSEvents-backed event-driven
# wake on macOS) when available, falls back to cadenced polling when
# fswatch isn't installed. Both paths are bandwidth-zero while waiting.
#
# Future: when agentic-mail v0.2+ ships urgent/blocking message types,
# this script's wake mechanism may be replaced or augmented by
# `mail-status --wait-for-urgent <thread>`. The contract (block until
# RESOLVED line) is invariant; the wake mechanism is pluggable.
#
# Usage:
#   wait-for-resolution.sh <escalation-file> [options]
#
# Options:
#   --timeout <seconds>        Maximum wait (default 14400 = 4 hours).
#                              On timeout, writes a follow-up
#                              ESCALATION-<ts>-timeout.md and exits 2.
#   --poll-interval <seconds>  Polling cadence when fswatch unavailable
#                              (default 30).
#   --no-followup              On timeout, exit 2 without writing a
#                              follow-up escalation file.
#   --quiet                    Suppress informational stderr output.
#
# Exit codes:
#   0  RESOLVED line found. The matched line is printed to stdout.
#   1  BLOCKED line found. The matched line is printed to stdout;
#      caller should mark task as blocked per EXECUTION-MODEL.md
#      §"Permanent escalation".
#   2  Timeout reached without resolution. Follow-up escalation written
#      (unless --no-followup).
#   3  Usage error.
#   4  Escalation file does not exist or is unreadable.
#   130 Interrupted (Ctrl-C).
#
# Repo-portable: takes the escalation file as an argument, hardcodes
# nothing about agentic-ops layout. Drop this script into any consumer
# repo's `.agents/skills/escalation-dormancy/scripts/` and it works.

set -euo pipefail

# ---------- defaults ----------
TIMEOUT=14400
POLL=30
QUIET=0
NO_FOLLOWUP=0

# ---------- arg parse ----------
ESC_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout)        TIMEOUT="$2"; shift 2 ;;
    --poll-interval)  POLL="$2"; shift 2 ;;
    --no-followup)    NO_FOLLOWUP=1; shift ;;
    --quiet)          QUIET=1; shift ;;
    -h|--help)        sed -n '2,40p' "$0"; exit 0 ;;
    -*)               echo "unknown flag: $1" >&2; exit 3 ;;
    *)                if [ -z "$ESC_FILE" ]; then ESC_FILE="$1"; shift
                      else echo "extra positional arg: $1" >&2; exit 3; fi ;;
  esac
done

if [ -z "$ESC_FILE" ]; then
  echo "usage: $(basename "$0") <escalation-file> [options]" >&2
  exit 3
fi
if [ ! -r "$ESC_FILE" ]; then
  echo "escalation file not readable: $ESC_FILE" >&2
  exit 4
fi

# ---------- helpers ----------
log() {
  [ "$QUIET" -eq 1 ] && return 0
  printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*" >&2
}

# Returns the matched line via stdout if found; non-zero exit if not.
match_resolved() { grep -m1 -E '^RESOLVED:' "$ESC_FILE" 2>/dev/null; }
match_blocked()  { grep -m1 -E '^BLOCKED:'  "$ESC_FILE" 2>/dev/null; }

write_followup() {
  local dir base ts followup body
  dir=$(dirname "$ESC_FILE")
  base=$(basename "$ESC_FILE" .md)
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  followup="$dir/${base}-timeout-${ts}.md"
  cat > "$followup" <<EOM
# Escalation: dormancy timeout follow-up

**Parent escalation:** $(basename "$ESC_FILE")
**Created:** $ts
**Status:** unresolved
**Reason:** dormancy contract timeout

## What happened

The original escalation has been in DORMANT state for ${TIMEOUT}s
(per .planning/EXECUTION-MODEL.md §"Escalation dormancy contract" —
"Dormancy timeout") without a RESOLVED or BLOCKED line appearing on
the parent file.

## Suggested user action

- Confirm the parent escalation is still actionable.
- If yes: resolve it per §"User-resolved escalation" by adding a
  \`RESOLVED:\` line at column 0 to the parent file.
- If no longer actionable: add a \`BLOCKED:\` line at column 0 to
  the parent file with the reason.
- If you have stopped working on this initiative: terminate the
  /goal session; the dormant agent is consuming nothing while
  blocked but cannot make progress.

The /goal session is still alive and continues to wait. It will
re-check the parent escalation file once this follow-up is
acknowledged or resolved.
EOM
  log "wrote follow-up escalation: $followup"
}

# ---------- pre-check: already resolved? ----------
if line=$(match_resolved); then
  log "already RESOLVED at start"
  printf '%s\n' "$line"
  exit 0
fi
if line=$(match_blocked); then
  log "already BLOCKED at start"
  printf '%s\n' "$line"
  exit 1
fi

# ---------- main loop ----------
START=$(date +%s)
DEADLINE=$((START + TIMEOUT))
HAVE_FSWATCH=0
if command -v fswatch >/dev/null 2>&1; then
  HAVE_FSWATCH=1
  log "watching $ESC_FILE via fswatch (timeout=${TIMEOUT}s)"
else
  log "fswatch not found; polling $ESC_FILE every ${POLL}s (timeout=${TIMEOUT}s; install fswatch for event-driven wake)"
fi

# Trap so Ctrl-C exits cleanly with code 130 and any background fswatch
# is reaped.
cleanup() {
  jobs -p 2>/dev/null | xargs -r kill 2>/dev/null || true
}
trap 'cleanup; exit 130' INT TERM

while true; do
  now=$(date +%s)
  if [ "$now" -ge "$DEADLINE" ]; then
    log "timeout reached after ${TIMEOUT}s without resolution"
    if [ "$NO_FOLLOWUP" -eq 0 ]; then
      write_followup
    fi
    exit 2
  fi

  if [ "$HAVE_FSWATCH" -eq 1 ]; then
    # fswatch -1 exits on first event. Use timeout-aware bound so we
    # re-check deadline even if no event arrives in a long stretch.
    remaining=$((DEADLINE - now))
    # Cap each fswatch wait at min(POLL*60, remaining) to avoid
    # blocking past the deadline. fswatch has no native timeout, so
    # we wrap it.
    wait_window=$(( POLL * 60 ))
    [ "$wait_window" -gt "$remaining" ] && wait_window=$remaining
    [ "$wait_window" -lt 1 ] && wait_window=1
    fswatch -1 "$ESC_FILE" >/dev/null 2>&1 &
    fs_pid=$!
    # Bound the wait
    ( sleep "$wait_window"; kill "$fs_pid" 2>/dev/null || true ) &
    sleep_pid=$!
    wait "$fs_pid" 2>/dev/null || true
    kill "$sleep_pid" 2>/dev/null || true
  else
    sleep "$POLL"
  fi

  # After wake (event or poll tick), re-check.
  if line=$(match_resolved); then
    log "RESOLVED detected"
    printf '%s\n' "$line"
    exit 0
  fi
  if line=$(match_blocked); then
    log "BLOCKED detected"
    printf '%s\n' "$line"
    exit 1
  fi
done
