# Noridoc: scripts

Path: @/scripts

### Overview

A single verification script that runs the full quality gate for claude-mode: Bash syntax check, Python compilation check, test suite execution, ShellCheck linting, and shfmt formatting diff.

### How it fits into the larger codebase

This is the "verify" target in @/Makefile and is the pre-submit quality gate. It validates every shell file (including `bin/claude-mode`, `install.sh`, all `lib/*.sh`, all `tests/*.sh`, and itself) plus the Python JSON tool. It is not part of the installed package -- it lives in the development checkout only.

### Core Implementation

The script performs five checks in sequence:

1. **Bash syntax**: `bash -n` on every shell file listed explicitly
2. **Python compile**: `python3 -m py_compile` on `lib/json_tool.py`
3. **Test suite**: runs `bash tests/run.sh`
4. **ShellCheck**: runs `shellcheck -x` on all shell files if the binary is available (vendored at `shellcheck-v0.10.0/shellcheck`)
5. **shfmt**: runs `shfmt -d -i 2 -ci` (diff mode, 2-space indent) on all shell files if the binary is available (vendored at `shfmt_v3.8.0_linux_amd64`)

The script uses a hardcoded list of shell files. It does not fail if ShellCheck or shfmt are absent; it prints a note and continues. The test suite run (`bash tests/run.sh`) does cause failure on test failure.

### Things to Know

- The shell file list is duplicated in `scripts/verify.sh` and must be kept in sync with new files
- ShellCheck and shfmt binaries are vendored at the repository root for CI environments without `apt-get` access
- The script runs `cd "$ROOT"` at the start, so all paths are relative to the repository root
