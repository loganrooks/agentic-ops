#!/usr/bin/env bash
# escalation-poller.sh
#
# Watch a /goal escalations directory for unresolved escalations and notify
# the supervisor (macOS user) via osascript when a new one appears or when
# previously-unresolved ones change status.
#
# Friction this addresses: F-007 (supervisor↔/goal coordination loop). When
# /goal escalates, the supervisor needs out-of-band notification — checking
# manually defeats the autonomy contract; sitting in the same chat blocks
# parallel work.
#
# Companion to .claude/skills/escalation-watch/SKILL.md (this repo).
# The Codex /goal side has its own wait script at
# .agents/skills/escalation-dormancy/scripts/wait-for-resolution.sh.
#
# Repo-portable: takes the escalations directory as a flag, hardcodes
# nothing about agentic-ops layout. Drop into any consumer repo's
# `scripts/` and run with `--dir <repo>/.planning/auto-execution/escalations`.
#
# Usage:
#   escalation-poller.sh [--dir PATH] [--interval SECONDS] [--once]
#                        [--no-notify] [--quiet]
#
# Defaults:
#   --dir       $PWD/.planning/auto-execution/escalations
#   --interval  30
#
# Behavior:
#   - On startup: scans the directory, captures the current set of files
#     and their resolution status as the BASELINE. Files already
#     RESOLVED at startup are recorded as such; files unresolved at
#     startup are recorded as such (no notification fires for them
#     unless their status later changes — i.e. you don't get spammed
#     with old escalations when starting up).
#   - Per tick: re-scans the directory. Notifies on:
#       (a) NEW file appears (regardless of status), and
#       (b) Previously-unresolved file becomes RESOLVED (so the
#           supervisor can confirm /goal noticed and can resume).
#   - Notification: macOS osascript "display notification".
#   - Logs to /tmp/escalation-poller.log unless --quiet.
#
# Compatible with macOS bash 3.2 (no associative arrays). Uses tempfile
# for state.

set -euo pipefail

# ---------- defaults ----------
ESC_DIR="${PWD}/.planning/auto-execution/escalations"
INTERVAL=30
RUN_ONCE=0
DO_NOTIFY=1
QUIET=0
LOG_FILE="/tmp/escalation-poller.log"

# ---------- parse args ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)        ESC_DIR="$2"; shift 2 ;;
    --interval)   INTERVAL="$2"; shift 2 ;;
    --once)       RUN_ONCE=1; shift ;;
    --no-notify)  DO_NOTIFY=0; shift ;;
    --quiet)      QUIET=1; shift ;;
    -h|--help)    sed -n '2,30p' "$0"; exit 0 ;;
    *)            echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ---------- helpers ----------
log() {
  if [ "$QUIET" -eq 0 ]; then
    printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$LOG_FILE"
  else
    printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*" >> "$LOG_FILE"
  fi
}

notify() {
  local title="$1" body="$2"
  if [ "$DO_NOTIFY" -eq 1 ] && command -v osascript >/dev/null 2>&1; then
    # Escape double quotes for AppleScript
    title="${title//\"/\\\"}"
    body="${body//\"/\\\"}"
    osascript -e "display notification \"$body\" with title \"$title\" sound name \"Submarine\"" >/dev/null 2>&1 || true
  fi
}

# Returns "RESOLVED" or "UNRESOLVED" by scanning the file for a line matching
# `RESOLVED:` at column 0 OR `**Status:** RESOLVED` (case-insensitive).
status_of() {
  local f="$1"
  if grep -qE '^RESOLVED:' "$f" 2>/dev/null; then
    printf 'RESOLVED'
  elif grep -qiE '^\*\*Status:\*\*[[:space:]]+resolved' "$f" 2>/dev/null; then
    printf 'RESOLVED'
  else
    printf 'UNRESOLVED'
  fi
}

# State files (one per state):
#   $STATE_DIR/seen      — list of paths seen in any prior tick
#   $STATE_DIR/<sha>     — last known status for the path whose sha1 = <sha>
STATE_DIR="$(mktemp -d -t escalation-poller-state.XXXXXX)"
trap 'rm -rf "$STATE_DIR"' EXIT
: > "$STATE_DIR/seen"

path_key() {
  printf '%s' "$1" | shasum | awk '{print $1}'
}

remember() {
  local f="$1" st="$2"
  local key; key=$(path_key "$f")
  printf '%s\n' "$st" > "$STATE_DIR/$key"
  if ! grep -qxF "$f" "$STATE_DIR/seen"; then
    printf '%s\n' "$f" >> "$STATE_DIR/seen"
  fi
}

prior_status() {
  local f="$1"
  local key; key=$(path_key "$f")
  if [ -f "$STATE_DIR/$key" ]; then
    cat "$STATE_DIR/$key"
  else
    printf 'NEW'
  fi
}

# ---------- baseline ----------
if [ ! -d "$ESC_DIR" ]; then
  log "directory does not exist: $ESC_DIR"
  log "creating it (no escalations to baseline)"
  mkdir -p "$ESC_DIR"
fi

baseline_count=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  st=$(status_of "$f")
  remember "$f" "$st"
  baseline_count=$((baseline_count + 1))
done < <(find "$ESC_DIR" -maxdepth 1 -type f -name 'ESCALATION-*.md' 2>/dev/null | sort)

log "baseline: watching $ESC_DIR (interval=${INTERVAL}s, files at start=$baseline_count)"

# ---------- loop ----------
tick() {
  local now_files
  now_files=$(find "$ESC_DIR" -maxdepth 1 -type f -name 'ESCALATION-*.md' 2>/dev/null | sort)

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local cur prior
    cur=$(status_of "$f")
    prior=$(prior_status "$f")

    if [ "$prior" = "NEW" ]; then
      local short
      short=$(basename "$f")
      log "NEW escalation: $short ($cur)"
      notify "/goal escalation" "$short is $cur"
      remember "$f" "$cur"
    elif [ "$prior" != "$cur" ]; then
      local short
      short=$(basename "$f")
      log "STATUS CHANGE: $short  $prior → $cur"
      notify "/goal escalation" "$short  $prior → $cur"
      remember "$f" "$cur"
    fi
  done <<< "$now_files"
}

if [ "$RUN_ONCE" -eq 1 ]; then
  tick
  log "ran once; exiting"
  exit 0
fi

while true; do
  tick
  sleep "$INTERVAL"
done
