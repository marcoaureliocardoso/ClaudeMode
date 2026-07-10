#!/usr/bin/env bash

# shellcheck disable=SC2034
CM_VERSION="0.1.1"
CM_DRY_RUN=${CM_DRY_RUN:-0}
CM_VERBOSE=${CM_VERBOSE:-0}
CM_ASSUME_YES=${CM_ASSUME_YES:-0}
CM_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CM_JSON_TOOL="$CM_ROOT/lib/json_tool.py"

cm_die() {
  printf 'claude-mode: ERROR: %s\n' "$*" >&2
  exit 1
}
cm_warn() { printf 'claude-mode: WARN: %s\n' "$*" >&2; }
cm_info() { printf 'claude-mode: %s\n' "$*"; }
cm_debug() { if [[ "$CM_VERBOSE" == 1 ]]; then printf 'claude-mode: DEBUG: %s\n' "$*" >&2 || true; fi; }

cm_quote_cmd() {
  local arg out=''
  for arg in "$@"; do
    printf -v arg '%q' "$arg"
    out="$out${out:+ }$arg"
  done
  printf '%s' "$out"
}

cm_run() {
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    printf 'claude-mode: DRY-RUN: %s\n' "$(cm_quote_cmd "$@")"
    return 0
  fi
  cm_debug "run: $(cm_quote_cmd "$@")"
  "$@"
}

cm_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || cm_die "required command not found: $1"
}

cm_realpath() {
  python3 -S - "$1" <<'PY'
import os,sys
print(os.path.realpath(sys.argv[1]))
PY
}

cm_project_hash() {
  python3 -S - "$1" <<'PY'
import hashlib,sys
print(hashlib.sha256(sys.argv[1].encode()).hexdigest()[:16])
PY
}

cm_resolve_project() {
  local requested=$1 allow_non_git=$2 candidate=''
  if [[ -n "$requested" ]]; then
    candidate=$requested
  elif candidate=$(git rev-parse --show-toplevel 2>/dev/null); then
    :
  elif [[ "$allow_non_git" == 1 ]]; then
    candidate=$PWD
  else
    cm_die 'not inside a Git repository; use --project PATH or --allow-non-git'
  fi
  [[ -d "$candidate" ]] || cm_die "project directory does not exist: $candidate"
  candidate=$(cm_realpath "$candidate")
  [[ "$candidate" != / ]] || cm_die 'refusing to use filesystem root as project'
  local home_real
  home_real=$(cm_realpath "$HOME")
  [[ "$candidate" != "$home_real" ]] || cm_die 'refusing to use HOME as project; choose a project directory'
  printf '%s' "$candidate"
}

cm_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

cm_version_of() {
  local cmd=$1
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" --version 2>/dev/null | head -n 1 || true
  fi
}

cm_json_string() {
  python3 -S - "$1" <<'PY'
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

cm_copy_json_snapshot() {
  local source=$1 target=$2
  mkdir -p "$(dirname "$target")"
  if [[ -f "$source" ]]; then
    python3 -S - "$source" "$target" <<'PY'
import json,os,sys,tempfile
src,dst=sys.argv[1:]
with open(src,encoding='utf-8') as f: data=json.load(f)
os.makedirs(os.path.dirname(dst),exist_ok=True)
fd,tmp=tempfile.mkstemp(prefix='.snapshot.',dir=os.path.dirname(dst))
with os.fdopen(fd,'w',encoding='utf-8') as f:
    json.dump(data,f,indent=2,sort_keys=True); f.write('\n')
os.chmod(tmp,0o600); os.replace(tmp,dst)
PY
  else
    printf '{}\n' >"$target"
    chmod 600 "$target"
  fi
}

cm_confirm() {
  local prompt=$1
  [[ "$CM_ASSUME_YES" == 1 ]] && return 0
  [[ -t 0 ]] || cm_die "$prompt; rerun with --yes"
  printf '%s [y/N] ' "$prompt" >&2
  local answer=''
  read -r answer
  [[ "$answer" == y || "$answer" == Y || "$answer" == yes || "$answer" == YES ]]
}
