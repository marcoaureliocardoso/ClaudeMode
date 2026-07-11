# Noridoc: scripts

Path: @/scripts

### Overview

Two scripts: a verification quality gate (`verify.sh`) and a standalone smart patch utility (`nori-patch.sh`) for applying fixes to the senior-swe skillset independently of claude-mode.

### How it fits into the larger codebase

`verify.sh` is the "verify" target in @/Makefile and is the pre-submit quality gate. It validates every shell file plus the Python JSON tool. `nori-patch.sh` is a standalone utility that applies smart patches independently of claude-mode. Neither is part of the installed package -- they live in the development checkout only.

### Core Implementation

**verify.sh** performs five checks in sequence:

1. **Bash syntax**: `bash -n` on every shell file listed explicitly
2. **Python compile**: `python3 -m py_compile` on `lib/json_tool.py`
3. **Test suite**: runs `bash tests/run.sh`
4. **ShellCheck**: runs `shellcheck -x` on all shell files if the binary is available (vendored at `shellcheck-v0.10.0/shellcheck`)
5. **shfmt**: runs `shfmt -d -i 2 -ci` (diff mode, 2-space indent) on all shell files if the binary is available (vendored at `shfmt_v3.8.0_linux_amd64`)

**nori-patch.sh** sources @/lib/patch.sh and applies 11 idempotent fixes for upstream bugs in `senior-swe@1.0.2`. Accepts `--project` or `--install-dir` to locate the `.claude/` directory. Respects `--dry-run` and `--verbose` flags.

### Things to Know

- The shell file list is duplicated in `scripts/verify.sh` and must be kept in sync with new files
- ShellCheck and shfmt binaries are vendored at the repository root for CI environments without `apt-get` access
- The script runs `cd "$ROOT"` at the start, so all paths are relative to the repository root
- `nori-patch.sh` derives `CM_PROJECT` from `--install-dir` by stripping a trailing `/.claude` when present
