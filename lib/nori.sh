#!/usr/bin/env bash

CM_NEUTRAL_NAME='claude-mode-neutral'
CM_NEUTRAL_DIR="$HOME/.nori/profiles/personal/$CM_NEUTRAL_NAME"

cm_nori_ensure_installed() {
  CM_NORI_INSTALLED_BY_TOOL=false
  if command -v nori-skillsets >/dev/null 2>&1; then return 0; fi
  cm_require_cmd npm
  cm_run npm install -g nori-skillsets
  CM_NORI_INSTALLED_BY_TOOL=true
  hash -r
  [[ "$CM_DRY_RUN" == 1 ]] || command -v nori-skillsets >/dev/null 2>&1 || cm_die 'Nori installation completed but nori-skillsets is not in PATH'
}

cm_nori_profile_find() {
  local name=$1 candidate
  for candidate in \
    "$HOME/.nori/profiles/personal/$name" \
    "$HOME/.nori/profiles/public/$name" \
    "$HOME/.nori/profiles/$name"; do
    [[ -f "$candidate/nori.json" ]] && { printf '%s' "$candidate"; return 0; }
  done
  return 1
}

cm_nori_init() {
  cm_run nori-skillsets --install-dir "$CM_PROJECT" --agent claude-code --non-interactive init
}

cm_nori_ensure_senior() {
  CM_SENIOR_PREEXISTING=false
  if cm_nori_profile_find senior-swe >/dev/null 2>&1; then
    CM_SENIOR_PREEXISTING=true
    return 0
  fi
  cm_run nori-skillsets download senior-swe
  [[ "$CM_DRY_RUN" == 1 ]] || cm_nori_profile_find senior-swe >/dev/null 2>&1 || cm_die 'senior-swe download could not be verified'
}

cm_nori_write_neutral() {
  local tmp
  mkdir -p "$(dirname "$CM_NEUTRAL_DIR")"
  mkdir -p "$CM_NEUTRAL_DIR"
  tmp=$(mktemp "$CM_NEUTRAL_DIR/.nori.json.XXXXXX")
  cat > "$tmp" <<EOF_JSON
{
  "description": "Empty compatibility skillset managed by claude-mode",
  "name": "$CM_NEUTRAL_NAME",
  "type": "skillset",
  "version": "1.0.0"
}
EOF_JSON
  chmod 600 "$tmp"
  mv "$tmp" "$CM_NEUTRAL_DIR/nori.json"
}

cm_nori_ensure_neutral() {
  CM_NEUTRAL_CREATED=false
  if [[ -d "$CM_NEUTRAL_DIR" ]]; then
    python3 -S "$CM_JSON_TOOL" validate-neutral "$CM_NEUTRAL_DIR" --name "$CM_NEUTRAL_NAME" || cm_die "existing $CM_NEUTRAL_NAME skillset is not empty or is not tool-owned"
    return 0
  fi
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info "DRY-RUN: create neutral Nori skillset at $CM_NEUTRAL_DIR"
  else
    cm_nori_write_neutral
  fi
  CM_NEUTRAL_CREATED=true
}

cm_nori_switch() {
  local name=$1
  cm_run nori-skillsets --install-dir "$CM_PROJECT" --agent claude-code --non-interactive switch "$name"
}

cm_nori_marker() {
  local marker="$CM_PROJECT/.claude/.nori-managed"
  [[ -f "$marker" ]] && cat "$marker" || true
}

cm_nori_clear_project() {
  cm_run nori-skillsets --install-dir "$CM_PROJECT" --agent claude-code --non-interactive clear
}

cm_nori_remove_neutral_if_owned() {
  [[ -d "$CM_NEUTRAL_DIR" ]] || return 0
  if python3 -S "$CM_JSON_TOOL" validate-neutral "$CM_NEUTRAL_DIR" --name "$CM_NEUTRAL_NAME"; then
    if [[ "$CM_DRY_RUN" == 1 ]]; then
      cm_info "DRY-RUN: remove $CM_NEUTRAL_DIR"
    else
      rm -rf "$CM_NEUTRAL_DIR"
    fi
  else
    cm_warn "preserving modified neutral skillset: $CM_NEUTRAL_DIR"
  fi
}
