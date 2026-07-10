#!/usr/bin/env bash

CM_PLUGIN_DEFAULT='superpowers@claude-plugins-official'

cm_plugin_matches_json() {
  if ! command -v claude >/dev/null 2>&1; then
    printf '[]\n'
    return 0
  fi
  local raw
  raw=$(claude plugin list --json 2>/dev/null) || cm_die 'failed to query Claude Code plugins'
  printf '%s\n' "$raw" | python3 -S "$CM_JSON_TOOL" plugin-matches
}

cm_plugin_count() {
  cm_plugin_matches_json | python3 -S -c 'import json,sys; print(len(json.load(sys.stdin)))'
}

cm_plugin_single_json() {
  local matches count
  matches=$(cm_plugin_matches_json)
  count=$(printf '%s' "$matches" | python3 -S -c 'import json,sys; print(len(json.load(sys.stdin)))')
  if ((count > 1)); then
    cm_die 'multiple Superpowers installations detected; remove duplicates before continuing'
  fi
  if ((count == 0)); then
    printf 'null\n'
  else
    printf '%s' "$matches" | python3 -S -c 'import json,sys; print(json.dumps(json.load(sys.stdin)[0],sort_keys=True))'
  fi
}

cm_plugin_field() {
  local object=$1 field=$2 default=${3:-}
  JSON_OBJECT="$object" FIELD="$field" DEFAULT="$default" python3 -S - <<'PY'
import json,os
obj=json.loads(os.environ['JSON_OBJECT'])
if obj is None: print(os.environ['DEFAULT'])
else:
    value=obj.get(os.environ['FIELD'],os.environ['DEFAULT'])
    if isinstance(value,bool): print(str(value).lower())
    elif isinstance(value,(dict,list)): print(json.dumps(value,sort_keys=True))
    else: print(value)
PY
}

cm_plugin_has_local_scope() {
  local object=$1
  JSON_OBJECT="$object" python3 -S - <<'PY'
import json,os
obj=json.loads(os.environ['JSON_OBJECT'])
scopes=obj.get('scopes',[]) if obj else []
if not scopes and obj and obj.get('scope'): scopes=[obj.get('scope')]
print('true' if scopes == ['local'] else 'false')
PY
}

cm_plugin_install_if_needed() {
  local existing
  existing=$(cm_plugin_single_json)
  CM_PLUGIN_INSTALLED_BY_TOOL=false
  CM_PLUGIN_PREEXISTING_ENABLED=false
  if [[ "$existing" == null ]]; then
    cm_run claude plugin install "$CM_PLUGIN_DEFAULT" --scope local
    # shellcheck disable=SC2034
    CM_PLUGIN_INSTALLED_BY_TOOL=true
    CM_PLUGIN_ID="$CM_PLUGIN_DEFAULT"
  else
    CM_PLUGIN_ID=$(cm_plugin_field "$existing" id)
    [[ "$(cm_plugin_has_local_scope "$existing")" == true ]] || cm_die "Superpowers is installed outside local scope ($CM_PLUGIN_ID); remove or migrate it first"
    # shellcheck disable=SC2034
    CM_PLUGIN_PREEXISTING_ENABLED=$(cm_plugin_field "$existing" enabled false)
  fi
  if [[ "$CM_DRY_RUN" != 1 ]]; then
    local after
    after=$(cm_plugin_single_json)
    [[ "$after" != null ]] || cm_die 'Superpowers installation could not be verified'
    CM_PLUGIN_ID=$(cm_plugin_field "$after" id)
  fi
}

cm_plugin_enable() {
  if [[ "$(cm_plugin_enabled_actual)" != true ]]; then
    cm_run claude plugin enable "$1" --scope local
  fi
}
cm_plugin_disable() {
  if [[ "$(cm_plugin_enabled_actual)" == true ]]; then
    cm_run claude plugin disable "$1" --scope local
  fi
}
cm_plugin_uninstall() { cm_run claude plugin uninstall "$1" --scope local --prune --yes; }

cm_plugin_enabled_actual() {
  local object
  object=$(cm_plugin_single_json)
  [[ "$object" == null ]] && {
    printf 'false'
    return
  }
  cm_plugin_field "$object" enabled false
}
