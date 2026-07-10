# Noridoc: bin

Path: @/bin

### Overview

The single CLI entry point for claude-mode. Parses arguments, dispatches to commands (install, use, status, doctor, uninstall, help), and manages the transaction model that ensures atomic mode switches with rollback on failure.

### How it fits into the larger codebase

`bin/claude-mode` sources all five library modules from @/lib at startup and is the only file that does so. It defines the transaction lifecycle, all user-facing command functions, the EXIT trap for rollback, and the argument parsing loop. The binary that users invoke at the command line.

### Core Implementation

**Argument parsing**: Positional arguments determine the command (install, use, status, doctor, uninstall, help). Global flags (`--project`, `--allow-non-git`, `--dry-run`, `--verbose`, `--yes`, `--json`, `--purge-global`, `--version`, `--help`) are parsed in a `while` loop before project resolution. After parsing, `cm_resolve_project` resolves the project root, then `cm_state_init_paths` sets up state directories.

**Transaction model**: Each mutating command follows `begin -> mutate -> validate -> commit`:
1. `cm_begin_transaction` acquires the lock, snapshots `~/.claude/settings.json`, records the current Nori marker and plugin state
2. Operations are performed (mutations)
3. `cm_validate_mode` verifies the expected mode matches observed mode
4. `cm_commit_transaction` clears the snapshot, releases the lock

**EXIT trap rollback** (`cm_exit_handler`): On any non-zero exit during an active transaction, the handler restores in reverse order:
- Settings snapshot is copied back to `~/.claude/settings.json`
- Nori marker is restored to its previous value (senior-swe or neutral)
- Plugin is reverted (enabled/disabled/uninstalled) to its previous state
- Lock is released

Only the main process PID runs the full rollback; subshells exit immediately.

**Command implementations**:

- `cm_install` -- Creates state, snapshots baseline settings, ensures Nori is installed, initializes Nori for the project, downloads senior-swe if missing, creates the neutral skillset, installs or verifies the Superpowers plugin, disables the plugin, switches Nori to senior-swe, snapshots post-install settings, writes state with ownership tracking
- `cm_use` -- Switches between `senior` and `superpowers` modes by toggling plugin state and Nori skillset, updates `expected_mode` in state
- `cm_status` -- Calls `cm_status_json` which assesses the full system state by reading the Nori marker, querying plugin list, cross-referencing against saved state
- `cm_doctor` -- Runs status plus extra checks (python3, claude, nori availability, neutral skillset validity), exits non-zero if any issues
- `cm_uninstall` -- Disables/uninstalls plugin based on ownership, restores pre-existing plugin state, runs three-way settings merge to revert tool-added settings, clears Nori project config, optionally purges global nori-skillsets if owned, validates resulting mode is "none"

**Transactions and state**: `CM_TX_ACTIVE`, `CM_TX_COMMITTED`, `CM_TX_PLUGIN_CREATED`, `CM_TX_PLUGIN_ID`, `CM_TX_PREV_PLUGIN_ENABLED`, `CM_TX_PREV_MARKER`, `CM_TX_SNAPSHOT`, and `CM_TX_ROLLBACK_NORI` track what needs to be undone on failure.

### Things to Know

- `umask 077` is set at the top of the script, ensuring all created files and directories are only accessible by the owner
- `set -Eeuo pipefail` ensures strict error handling; the `-E` flag is necessary so the EXIT trap fires on errors inside sourced functions
- `BASHPID` is used for rollback PID filtering instead of `$` to correctly handle subshells
- The `--dry-run` flag short-circuits every mutation but still performs the transaction lifecycle (lock, snapshot, commit) to validate the operation would succeed
- `cm_other_installed_states` uses a Python script to walk the entire state directory tree, excluding the current project's state, to prevent `--purge-global` from breaking other projects
- Version is printed from the `CM_VERSION` constant defined in @/lib/common.sh
