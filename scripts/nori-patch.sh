#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/patch.sh
source "$ROOT/lib/patch.sh"

usage() {
  cat <<'USAGE'
Usage:
  nori-patch.sh --project PATH
  nori-patch.sh --install-dir PATH

Options:
  --project PATH       Project root directory (patches .claude/ inside it)
  --install-dir PATH   Direct path to the install directory (e.g., ~/.claude)
  --dry-run            Print patches without applying them
  --verbose            Show diagnostic messages
  -h, --help           Show this help

Description:
  Applies fixes for 11 known upstream bugs in the senior-swe@1.0.2 skillset.
  Each patch is idempotent — safe to run multiple times. Patches silently skip
  if the bug is already fixed (e.g., by a future upstream release).
USAGE
}

CM_INSTALL_DIR=''
CM_DRY_RUN=0
CM_VERBOSE=0

while (($#)); do
  case "$1" in
    --project)
      [[ $# -ge 2 ]] || {
        echo 'ERROR: --project requires a path' >&2
        exit 1
      }
      CM_PROJECT=$2
      CM_INSTALL_DIR="$CM_PROJECT/.claude"
      shift 2
      ;;
    --install-dir)
      [[ $# -ge 2 ]] || {
        echo 'ERROR: --install-dir requires a path' >&2
        exit 1
      }
      CM_INSTALL_DIR=$2
      shift 2
      ;;
    --dry-run)
      CM_DRY_RUN=1
      shift
      ;;
    --verbose)
      CM_VERBOSE=1
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "$CM_INSTALL_DIR" ]] || {
  echo 'ERROR: --project or --install-dir is required' >&2
  usage >&2
  exit 1
}
[[ -d "$CM_INSTALL_DIR" ]] || {
  echo "ERROR: directory not found: $CM_INSTALL_DIR" >&2
  exit 1
}

# Determine CM_PROJECT so patches reference correct .claude/ paths.
# The patch functions target files at $CM_PROJECT/.claude/...
# If install-dir already ends with /.claude, derive CM_PROJECT from parent.
if [[ "$CM_INSTALL_DIR" == */.claude ]]; then
  CM_PROJECT="${CM_INSTALL_DIR%/.claude}"
else
  CM_PROJECT="$CM_INSTALL_DIR"
fi

cm_nori_apply_patches
echo 'Patches applied successfully.'
