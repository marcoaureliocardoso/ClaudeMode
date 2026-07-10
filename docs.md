# Noridoc: claude-mode

Path: @/

### Overview

claude-mode is a Bash CLI tool (v0.1.1) that manages concurrent installation of the Nori senior-swe skillset and the Claude Code Superpowers plugin on a per-project basis. It ensures only one mode is active at a time, provides rollback on failure, and preserves user settings changes through install/uninstall cycles.

### How it fits into the larger codebase

This is the repository root. The project has six top-level directories:

- **@/bin** -- Single CLI entry point `claude-mode`, argument parsing, command dispatch, transaction lifecycle
- **@/lib** -- Five shell library modules and one Python module implementing all core operations
- **@/tests** -- Behavioral test suite with mock external dependencies
- **@/scripts** -- Verification quality gate (lint, syntax check, test run)
- **@/docs** -- Pre-development design specifications and plans
- **@/tests/helpers** -- Test harness and mock executable generators

The boundary between shell and Python: filesystem operations, variable management, and process coordination are in shell. All JSON manipulation (parsing, merging, writing, validation) is delegated to `lib/json_tool.py` via subprocess, keeping complex data logic in a more reliable language.

System invariants:
1. The tool never edits the Claude plugin registry directly -- it always uses `claude plugin` subcommands
2. The tool never calls `nori-skillsets factory-reset` or similar destructive Nori commands
3. The neutral skillset (`claude-mode-neutral`) is an empty compatibility skillset that is always validated before removal to avoid deleting user-modified content
4. Settings restore is done via a three-way merge (base, post-install, current) to preserve user changes
5. Every mutating operation follows a begin-mutate-validate-commit transaction model with EXIT trap rollback

### Core Implementation

**Install flow** (`cm_install`):
1. Create state tracking at `$XDG_STATE_HOME/claude-mode/<sha256>/`
2. Snapshot `~/.claude/settings.json` as baseline
3. Install `nori-skillsets` via npm if missing
4. Run `nori-skillsets init` for the project
5. Download `senior-swe` profile if not present
6. Create empty `claude-mode-neutral` profile if not present
7. Install `superpowers@claude-plugins-official` plugin at local scope if missing
8. Disable the plugin, switch Nori to senior-swe
9. Snapshot settings as "post-install" state
10. Write all ownership flags to state.json

**Use flow** (`cm_use`): Toggles between two modes:
- "senior": Nori senior-swe active, Superpowers plugin disabled
- "superpowers": Nori claude-mode-neutral active, Superpowers plugin enabled

**Uninstall flow** (`cm_uninstall`):
1. Disable plugin; if tool-owned, uninstall it; if pre-existing enabled, re-enable it
2. Clear Nori project configuration
3. Three-way merge settings (base -> post -> current) to remove tool-added keys while preserving user changes
4. Remove neutral skillset if tool-created and unmodified
5. Update state to installed=false
6. Optionally purge global nori-skillsets if tool-installed and no other projects use it

**Transaction model**: All mutating commands use `cm_begin_transaction` / `cm_commit_transaction` with a rollback handler on EXIT. The handler restores settings, plugin state, and Nori marker in reverse order.

**State persistence**: JSON state is stored at `$XDG_STATE_HOME/claude-mode/<project-hash>/state.json`. The hash is the first 16 hex chars of SHA-256 of the project path, keeping state directory names short and deterministic.

### Things to Know

- `umask 077` is set in both `bin/claude-mode` and `install.sh`, ensuring all created files and directories are only accessible by the owner
- The project uses `set -Eeuo pipefail` throughout for strict error handling; `-E` is necessary for EXIT trap to fire on errors inside sourced functions
- The three-way merge in `json_tool.py` (`settings-merge` command) handles deep dictionary merging and list diffing. It records conflicts in a separate file for user notification
- Per-project state is stored at `$XDG_STATE_HOME/claude-mode/<sha256-hash>/` with backup snapshots stored in a `backups/` subdirectory
- ShellCheck 0 warnings, shfmt formatting applied as of v0.1.1; both linting tools are vendored in the repository
- The `--dry-run` flag shows all mutations without applying them, while still running the transaction lifecycle to validate the operation would succeed
