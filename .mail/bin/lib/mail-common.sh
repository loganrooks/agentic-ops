#!/usr/bin/env bash

set -euo pipefail

MAIL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/constants.sh
source "$MAIL_LIB_DIR/constants.sh"
BUDGET_LOCK_MAX_TRIES=20

error_exit() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage_error() {
  printf 'usage error: %s\n' "$*" >&2
  exit 2
}

role_is_valid() {
  case "$1" in
    claude | codex | human) return 0 ;;
    *) return 1 ;;
  esac
}

kind_is_valid() {
  case "$1" in
    question | answer | notice | request | ack) return 0 ;;
    *) return 1 ;;
  esac
}

priority_is_valid() {
  case "$1" in
    normal | high | urgent) return 0 ;;
    *) return 1 ;;
  esac
}

bool_is_valid() {
  case "$1" in
    true | false) return 0 ;;
    *) return 1 ;;
  esac
}

decision_class_is_valid() {
  case "$1" in
    low-stakes | high-stakes) return 0 ;;
    *) return 1 ;;
  esac
}

trim_value() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

option_value_or_die() {
  local option="$1"
  local value="${2:-}"
  if [ -z "$value" ] || [[ "$value" == --* ]]; then
    usage_error "missing value for $option"
  fi
  printf '%s\n' "$value"
}

workspace_path() {
  local workspace="$1"
  mkdir -p "$workspace/.mail"
  cd "$workspace" && pwd
}

ensure_role_dirs() {
  local workspace="$1"
  local role
  for role in claude codex human; do
    mkdir -p \
      "$workspace/.mail/$role/inbox/.tmp" \
      "$workspace/.mail/$role/processed" \
      "$workspace/.mail/$role/archive"
  done
}

iso_utc_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

message_nonce() {
  od -An -N4 -tx1 /dev/urandom | tr -d ' \n'
}

slugify() {
  local input="$1"
  printf '%s' "$input" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

safe_archive_key() {
  local input="${1:-unknown-thread}"
  local safe
  safe="$(printf '%s' "$input" | sed -E 's/[^A-Za-z0-9._-]+/_/g; s/^[.]+/_/; s/^[.]+$//')"
  [ -n "$safe" ] || safe="unknown-thread"
  printf '%s\n' "$safe"
}

json_escape() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//$'\n'/\\n}"
  input="${input//$'\r'/\\r}"
  input="${input//$'\t'/\\t}"
  printf '%s' "$input"
}

yaml_quote() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//$'\n'/\\n}"
  input="${input//$'\r'/\\r}"
  input="${input//$'\t'/\\t}"
  printf '"%s"' "$input"
}

frontmatter_value() {
  local file="$1"
  local field="$2"
  awk -v key="$field" '
    BEGIN { in_fm = 0; seen = 0 }
    /^---[[:space:]]*$/ {
      if (seen == 0) { in_fm = 1; seen = 1; next }
      exit
    }
    in_fm == 1 {
      split($0, parts, ":")
      if (parts[1] == key) {
        sub("^[^:]*:[[:space:]]*", "", $0)
        if ($0 ~ /^".*"$/) {
          value = substr($0, 2, length($0) - 2)
          out = ""
          escaped = 0
          for (i = 1; i <= length(value); i++) {
            c = substr(value, i, 1)
            if (escaped == 1) {
              if (c == "n") { out = out "\n" }
              else if (c == "r") { out = out "\r" }
              else if (c == "t") { out = out "\t" }
              else { out = out c }
              escaped = 0
            } else if (c == "\\") {
              escaped = 1
            } else {
              out = out c
            }
          }
          print out
        } else {
          print $0
        }
        exit
      }
    }
  ' "$file"
}

message_files() {
  local workspace="$1"
  [ -d "$workspace/.mail" ] || return 0
  find "$workspace/.mail" \
    \( -path '*/.tmp/*' -o -path "$workspace/.mail/attachments" -o -path "$workspace/.mail/attachments/*" \) -prune \
    -o -type f -name '*.md' -print
}

count_thread_messages() {
  local workspace="$1"
  local thread_id="$2"
  local count=0
  local file
  while IFS= read -r file; do
    if [ "$(frontmatter_value "$file" thread_id)" = "$thread_id" ]; then
      count=$((count + 1))
    fi
  done < <(message_files "$workspace")
  printf '%s\n' "$count"
}

budget_file() {
  printf '%s/.mail/.budget.json\n' "$1"
}

budget_lock_dir() {
  printf '%s/.mail/.budget.lock\n' "$1"
}

parse_budget_entries() {
  local file="$1"
  local compact
  compact="$(tr -d '[:space:]' < "$file")"
  if [ "$compact" = "{}" ]; then
    return 0
  fi
  awk '
    BEGIN { in_counts = 0; seen_counts = 0; bad = 0 }
    /^[[:space:]]*"phase_counts"[[:space:]]*:[[:space:]]*\{[[:space:]]*$/ {
      in_counts = 1
      seen_counts = 1
      next
    }
    in_counts == 1 && /^[[:space:]]*\}[,]?[[:space:]]*$/ {
      in_counts = 0
      next
    }
    in_counts == 1 {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line == "") { next }
      if (substr(line, 1, 1) != "\"") { bad = 1; next }
      key = ""
      escaped = 0
      for (i = 2; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (escaped == 1) {
          key = key "\\" c
          escaped = 0
        } else if (c == "\\") {
          escaped = 1
        } else if (c == "\"") {
          break
        } else {
          key = key c
        }
      }
      if (i > length(line) || escaped == 1) { bad = 1; next }
      rest = substr(line, i + 1)
      if (rest !~ /^[[:space:]]*:[[:space:]]*[0-9]+,?[[:space:]]*$/) { bad = 1; next }
      value = rest
      sub(/^[[:space:]]*:[[:space:]]*/, "", value)
      sub(/,?[[:space:]]*$/, "", value)
      printf "%s\t%s\n", key, value
    }
    END {
      if (bad == 1 || seen_counts == 0 || in_counts == 1) { exit 1 }
    }
  ' "$file"
}

read_budget_count() {
  local workspace="$1"
  local phase_id="$2"
  local file
  local escaped_phase
  local entries
  local key
  local value
  file="$(budget_file "$workspace")"
  [ -f "$file" ] || {
    printf '0\n'
    return
  }
  escaped_phase="$(json_escape "$phase_id")"
  entries="$(parse_budget_entries "$file")" || error_exit "corrupt budget file: $file"
  if [ -z "$entries" ]; then
    printf '0\n'
    return
  fi
  while IFS=$'\t' read -r key value; do
    if [ "$key" = "$escaped_phase" ]; then
      printf '%s\n' "$value"
      return
    fi
  done <<< "$entries"
  printf '0\n'
}

write_budget_count() {
  local workspace="$1"
  local phase_id="$2"
  local count="$3"
  local file
  local tmp
  local escaped_phase
  local entries=()
  local entries_text
  local key
  local value
  local index
  file="$(budget_file "$workspace")"
  tmp="${file}.tmp.$$"
  escaped_phase="$(json_escape "$phase_id")"
  if [ -f "$file" ]; then
    entries_text="$(parse_budget_entries "$file")" || error_exit "corrupt budget file: $file"
    while IFS=$'\t' read -r key value; do
      [ -n "$key" ] || continue
      if [ -n "$key" ] && [ "$key" != "$escaped_phase" ]; then
        entries+=("    \"$key\": $value")
      fi
    done <<< "$entries_text"
  fi
  entries+=("    \"$escaped_phase\": $count")
  {
    printf '{\n  "phase_counts": {\n'
    for index in "${!entries[@]}"; do
      if [ "$index" -lt "$((${#entries[@]} - 1))" ]; then
        printf '%s,\n' "${entries[$index]}"
      else
        printf '%s\n' "${entries[$index]}"
      fi
    done
    printf '  }\n}\n'
  } > "$tmp"
  mv "$tmp" "$file"
}

acquire_budget_lock() {
  local workspace="$1"
  local lock
  local tries=0
  lock="$(budget_lock_dir "$workspace")"
  until mkdir "$lock" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt "$BUDGET_LOCK_MAX_TRIES" ]; then
      error_exit "budget-lock-timeout"
    fi
    sleep 1
  done
  printf '%s\n' "$lock"
}

parse_iso_epoch() {
  local timestamp="$1"
  local normalized
  if date -u -d "$timestamp" '+%s' >/dev/null 2>&1; then
    date -u -d "$timestamp" '+%s'
    return 0
  fi
  if date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$timestamp" '+%s' >/dev/null 2>&1; then
    date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$timestamp" '+%s'
    return 0
  fi
  normalized="$(printf '%s' "$timestamp" | sed -E 's/([+-][0-9]{2}):([0-9]{2})$/\1\2/')"
  if date -j -f '%Y-%m-%dT%H:%M:%S%z' "$normalized" '+%s' >/dev/null 2>&1; then
    date -j -f '%Y-%m-%dT%H:%M:%S%z' "$normalized" '+%s'
    return 0
  fi
  return 1
}

iso8601_is_valid() {
  local timestamp="$1"
  [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$ ]] || return 1
  parse_iso_epoch "$timestamp" >/dev/null
}

is_past_iso_utc() {
  local timestamp="$1"
  local timestamp_epoch
  local now_epoch
  [ -n "$timestamp" ] || return 1
  [ "$timestamp" = "null" ] && return 1
  timestamp_epoch="$(parse_iso_epoch "$timestamp")" || return 1
  now_epoch="$(date -u '+%s')"
  [ "$timestamp_epoch" -lt "$now_epoch" ]
}

phase_id_default() {
  local workspace="${1:-$PWD}"
  git -C "$workspace" symbolic-ref --quiet --short HEAD 2>/dev/null ||
    git -C "$workspace" rev-parse --abbrev-ref HEAD 2>/dev/null ||
    printf 'unknown-phase\n'
}
