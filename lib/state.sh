#!/usr/bin/env bash

cm_state_init_paths() {
  local root=${XDG_STATE_HOME:-$HOME/.local/state}
  CM_PROJECT_KEY=$(cm_project_hash "$CM_PROJECT")
  CM_STATE_DIR="$root/claude-mode/$CM_PROJECT_KEY"
  CM_STATE_FILE="$CM_STATE_DIR/state.json"
  CM_BACKUP_DIR="$CM_STATE_DIR/backups"
  # shellcheck disable=SC2034
  CM_BASE_SETTINGS="$CM_BACKUP_DIR/claude-settings.before.json"
  # shellcheck disable=SC2034
  CM_POST_SETTINGS="$CM_BACKUP_DIR/claude-settings.after-nori.json"
  # shellcheck disable=SC2034
  CM_CURRENT_SETTINGS="$CM_BACKUP_DIR/claude-settings.before-uninstall.json"
  # shellcheck disable=SC2034
  CM_MERGED_SETTINGS="$CM_BACKUP_DIR/claude-settings.merged.json"
  # shellcheck disable=SC2034
  CM_CONFLICTS_FILE="$CM_BACKUP_DIR/settings-conflicts.json"
  # shellcheck disable=SC2034
  CM_CLAUDE_SETTINGS="$HOME/.claude/settings.json"
}

cm_state_create() {
  mkdir -p "$CM_BACKUP_DIR"
  chmod 700 "$CM_STATE_DIR" "$CM_BACKUP_DIR" 2>/dev/null || true
  python3 -S "$CM_JSON_TOOL" state-create "$CM_STATE_FILE" --project "$CM_PROJECT" --tool-version "$CM_VERSION"
}

cm_state_exists() { [[ -f "$CM_STATE_FILE" ]]; }

cm_state_get() {
  local path=$1 default=${2-}
  if [[ -n "${2+x}" ]]; then
    python3 -S "$CM_JSON_TOOL" state-get "$CM_STATE_FILE" "$path" --default "$default"
  else
    python3 -S "$CM_JSON_TOOL" state-get "$CM_STATE_FILE" "$path"
  fi
}

cm_state_set() {
  python3 -S "$CM_JSON_TOOL" state-set "$CM_STATE_FILE" "$@"
}
