#!/usr/bin/env bash

MAIL_CONSTANTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIL_CONSTANTS_ROOT="$(cd "${MAIL_CONSTANTS_DIR}/../.." && pwd)"
MAIL_SPEC_PATH="${MAIL_SPEC_PATH:-${MAIL_CONSTANTS_ROOT}/docs/protocols/AGENT-MAILBOX-v0.md}"

read_spec_constant() {
  local name="$1"
  awk -F '|' -v target="$name" '
    $2 ~ target {
      value = $3
      gsub(/`/, "", value)
      gsub(/\([^)]*\)/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$MAIL_SPEC_PATH"
}

if [ -f "$MAIL_SPEC_PATH" ]; then
  PROTOCOL_VERSION="$(read_spec_constant "PROTOCOL_VERSION")"
  THREAD_CAP_MESSAGES="$(read_spec_constant "THREAD_CAP_MESSAGES")"
  PER_PHASE_BUDGET_MESSAGES="$(read_spec_constant "PER_PHASE_BUDGET_MESSAGES")"
  BODY_HARD_CAP_BYTES="$(read_spec_constant "BODY_HARD_CAP_BYTES")"
else
  PROTOCOL_VERSION=0
  THREAD_CAP_MESSAGES=5
  PER_PHASE_BUDGET_MESSAGES=20
  BODY_HARD_CAP_BYTES=262144
fi

case "$PROTOCOL_VERSION:$THREAD_CAP_MESSAGES:$PER_PHASE_BUDGET_MESSAGES:$BODY_HARD_CAP_BYTES" in
  *[!0-9:]* | *::* | :* | *:)
    printf 'error: failed to parse protocol constants from %s\n' "$MAIL_SPEC_PATH" >&2
    false
    ;;
esac
