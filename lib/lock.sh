#!/usr/bin/env bash

CM_LOCK_HELD=0

cm_release_lock() {
  if [[ "$CM_LOCK_HELD" == 1 && -n "${CM_LOCK_DIR:-}" ]]; then
    rm -rf "$CM_LOCK_DIR"
    CM_LOCK_HELD=0
  fi
}

cm_acquire_lock() {
  mkdir -p "$CM_STATE_DIR"
  CM_LOCK_DIR="$CM_STATE_DIR/lock"
  if mkdir "$CM_LOCK_DIR" 2>/dev/null; then
    printf '%s\n' "$$" > "$CM_LOCK_DIR/pid"
    CM_LOCK_HELD=1
    return 0
  fi
  local pid=''
  [[ -f "$CM_LOCK_DIR/pid" ]] && pid=$(cat "$CM_LOCK_DIR/pid" 2>/dev/null || true)
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    cm_die "another claude-mode process holds the project lock (pid $pid)"
  fi
  cm_warn 'removing stale project lock'
  rm -rf "$CM_LOCK_DIR"
  mkdir "$CM_LOCK_DIR" || cm_die 'could not acquire project lock'
  printf '%s\n' "$$" > "$CM_LOCK_DIR/pid"
  CM_LOCK_HELD=1
}
