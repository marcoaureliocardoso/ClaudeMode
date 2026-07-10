# Noridoc: tests

Path: @/tests

### Overview

A behavioral test suite for claude-mode that runs 11 integration-style tests against the real CLI binary, using mocked external dependencies. Tests are executed in parallel (3 workers at a time) against an isolated filesystem environment.

### How it fits into the larger codebase

This is the sole test suite for the project, invoked via `make test` or directly with `bash tests/run.sh`. It sources helpers from @/tests/helpers to construct mock environments, then runs each test function in a subprocess worker. Assertions cover the complete lifecycle: install, status, use (switch), doctor, uninstall, dry-run, rollback, and error handling.

### Core Implementation

**Architecture**: The runner forks up to 3 parallel workers, each executing a single test function in a child `bash` process. Results are written to files and collected after all workers in a batch complete. This gives a balance between parallelism and manageable output.

**Test cases** (defined as paired arrays `CASE_LABELS` and `CASE_FUNCTIONS`):

1. **install_and_status** -- fresh install from empty state, verifies plugin disabled, Nori marker written, neutral skillset created
2. **install_is_idempotent** -- installing twice only runs `plugin install` once
3. **switches_are_mutually_exclusive** -- install, use superpowers (plugin enabled, neutral marker), use senior (plugin disabled, senior marker)
4. **doctor_detects_simultaneous_activation** -- install then manually enable plugin; doctor must fail with "simultaneously active"
5. **conflicting_plugin_installations_are_rejected** -- pre-seed multiple superpowers plugins; install must reject
6. **dry_run_does_not_mutate** -- no files created, no plugins installed
7. **uninstall_restores_user_settings** -- install with user settings, modify settings, uninstall verifies user changes preserved and tool-added keys removed
8. **status_without_install** -- reports mode=none, installed=false
9. **failed_switch_rolls_back** -- `MOCK_FAIL_NORI_SWITCH` triggers nori failure; verifies plugin state and marker revert
10. **preexisting_plugin_restored** -- pre-existing enabled plugin is disabled on install, re-enabled on uninstall
11. **json_tool_error_context** -- verifies `json_tool.py` errors include the command name

**Coverage**: Each test calls `run_cli` (a wrapper that captures exit code and stderr/stdout), then uses helpers from @/tests/helpers/testlib.sh to assert state on files, plugin registries, and Nori markers.

### Things to Know

- Tests are run in parallel with up to 3 concurrent workers, each writing to a separate result file
- `TEST_SUITE_TMP` is cleaned on EXIT trap; test functions each create their own `TEST_TMP` within it
- The mock CLI (`$MOCK_BIN/claude`) and mock Nori (`$MOCK_BIN/nori-skillsets`) are shell scripts that manipulate simple JSON files rather than real plugin registries
- Plugin state is tracked in a flat JSON array at `$MOCK_CLAUDE_PLUGINS`, not the real Claude plugin system
- The `--worker` mode in @/tests/run.sh allows the script to re-invoke itself for each test function
