#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

shell_files=(bin/claude-mode install.sh scripts/verify.sh lib/*.sh tests/*.sh tests/helpers/*.sh)
bash -n "${shell_files[@]}"
python3 -S -m py_compile lib/json_tool.py
bash tests/run.sh

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${shell_files[@]}"
else
  printf 'NOTE: shellcheck not found; skipped.\n' >&2
fi

if command -v shfmt >/dev/null 2>&1; then
  shfmt -d -i 2 -ci "${shell_files[@]}"
else
  printf 'NOTE: shfmt not found; skipped.\n' >&2
fi
