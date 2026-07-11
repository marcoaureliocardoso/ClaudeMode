# Noridoc: tests/helpers

Path: @/tests/helpers

### Overview

Provides a test harness and mock executables for running the claude-mode behavioral test suite in complete isolation, without touching real Claude Code, Nori, or npm installations.

### How it fits into the larger codebase

These helpers are sourced by @/tests/run.sh and are never used in production. They establish a fully controlled test environment by redirecting `HOME`, `XDG_STATE_HOME`, and `PATH` to temporary directories, then installing mock versions of `claude`, `nori-skillsets`, and `npm` that log calls and operate on in-memory plugin registries.

### Core Implementation

**testlib.sh** provides assertion functions (`assert_eq`, `assert_status`, `assert_contains`, `assert_file_exists`, `assert_file_not_exists`, `assert_json`), a `run_cli` wrapper that captures stdout/stderr and exit codes, and `run_test`/`finish_tests` for sequential test execution.

**setup_mocks.sh** provides:
- `setup_test_env` -- creates the temp environment, exports all mock paths, and calls the three mock constructors
- `make_mock_claude` -- writes a `claude` script that handles `plugin list`, `install`, `enable`, `disable`, `uninstall` against `$MOCK_CLAUDE_PLUGINS` (a JSON file acting as the plugin registry)
- `make_mock_nori` -- writes a `nori-skillsets` script that handles `init`, `download`, `list`, `switch`, `current`, `clear` operations, manipulating `$HOME/.nori/profiles/` and a project's `.claude/` directory; respects `MOCK_FAIL_NORI_SWITCH` to simulate switch failures and `MOCK_NORI_BUGGY_VERSION=1` to generate files with known upstream bugs for patch testing
- `make_mock_npm` -- writes a no-op `npm` that logs invocations

Every mock command logs its invocation to `$MOCK_LOG` for test assertions.

### Things to Know

- Mock executables are written to `$MOCK_BIN` and injected at front of `PATH`
- The mock `claude` uses `$MOCK_CLAUDE_PLUGINS` JSON file as its plugin registry, allowing tests to pre-seed plugin states
- `MOCK_FAIL_NORI_SWITCH` environment variable triggers a forced failure when `nori-skillsets switch` targets a specific name, used to test rollback behavior
- `MOCK_NORI_BUGGY_VERSION=1` causes the `download` mock to generate files with the 11 known upstream bugs from `senior-swe@1.0.2`, including buggy CLAUDE.md, buggy agents, and buggy skills — used to test smart patch application
- The mock `switch` command copies `subagents/` directory from the profile to `$install_dir/.claude/agents/`, matching real Nori behavior
- All mock paths are cleaned up automatically via the EXIT trap in @/tests/run.sh
