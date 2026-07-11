# Noridoc: lib

Path: @/lib

### Overview

Library modules that implement all of claude-mode's core operations: JSON processing, persistent state management, per-project locking, Claude Code plugin lifecycle, and Nori skillset management. Every file here is sourced by @/bin/claude-mode at startup.

### How it fits into the larger codebase

The lib directory is the engine room. @/bin/claude-mode sources all six files in dependency order: `common.sh` first (utility functions), then `state.sh` (paths/state I/O), `lock.sh` (mutex), `claude_plugin.sh` (plugin API), `nori.sh` (skillset API), and `patch.sh` (upstream bug fixes). All shell functions are prefixed with `cm_`. Global variables use the `CM_` prefix. The Python module `json_tool.py` is invoked as a subprocess for all JSON manipulation.

### Core Implementation

**common.sh** -- Defines logging (`cm_die`, `cm_warn`, `cm_info`, `cm_debug`), command execution (`cm_run` which respects `--dry-run`), project resolution (`cm_resolve_project` which requires a Git repository unless `--allow-non-git` is passed), JSON string quoting (`cm_json_string`), snapshot copying via tempfile+atomic replace, and user confirmation prompts.

**state.sh** -- Manages persistent JSON state at `$XDG_STATE_HOME/claude-mode/<sha256-hash>/state.json`. Initializes all path variables (`CM_STATE_DIR`, `CM_BACKUP_DIR`, `CM_CLAUDE_SETTINGS`, etc.) via `cm_state_init_paths`. Provides `cm_state_get`, `cm_state_set`, `cm_state_create`, and `cm_state_exists`. Paths include settings snapshots taken at install, post-Nori-init, and pre-uninstall for the three-way merge.

**lock.sh** -- Directory-based per-project locking. Lock is stored at `$CM_STATE_DIR/lock/` with the PID written to `lock/pid`. Stale lock detection: if the PID no longer exists, the lock is removed and re-acquired. The lock is acquired at the start of a transaction and released on commit or via `cm_release_lock` in the EXIT trap.

**claude_plugin.sh** -- All interactions with `claude plugin` subcommands. `cm_plugin_matches_json` pipes the full plugin list through `json_tool.py plugin-matches` which normalizes and filters for "superpowers" plugins. `cm_plugin_install_if_needed` handles the install-or-verify-existing logic, tracking whether the tool installed the plugin or it pre-existed. Functions wrap `claude plugin enable/disable/uninstall` with `--scope local`.

**nori.sh** -- All interactions with `nori-skillsets`. Manages the neutral skillset (`claude-mode-neutral`) lifecycle: creation, validation, removal. Installs nori-skillsets via npm if missing. Downloads senior-swe if not already present. Switches skillsets via `nori-skillsets switch`. Reads the `.nori-managed` marker file for current state. The neutral skillset is an empty compatibility skillset stored at `$HOME/.nori/profiles/personal/claude-mode-neutral/`.

**patch.sh** -- Smart patches for known upstream bugs in the `senior-swe@1.0.2` skillset. Exports `cm_nori_apply_patches()` which calls 11 individual patch functions. Each patch has a pattern-detection guard: it checks whether the buggy pattern still exists in the target file before applying the fix. This ensures idempotency (safe to re-run) and version-awareness (patches silently skip when upstream releases a fix). Called from `cm_install()` and `cm_use senior` in @/bin/claude-mode. Also sourced by the standalone `scripts/nori-patch.sh`.

**json_tool.py** -- A pure-standard-library Python CLI providing subcommands for JSON manipulation. Key operations:
- `plugin-matches` -- reads Claude plugin JSON from stdin, normalizes objects, filters for Superpowers-related plugins
- `state-create`, `state-get`, `state-set` -- atomic read/write of the state JSON file using tempfile+os.replace
- `settings-merge` -- three-way merge of `~/.claude/settings.json` (base, post-install, current) that preserves user changes
- `validate-neutral` -- checks that a Nori skillset directory contains only an unmodified `nori.json` with expected content
- `emit-status` -- constructs the structured status JSON from CLI arguments

### Things to Know

- All JSON writes use an atomic write pattern: write to a tempfile in the same directory, `os.fsync`, then `os.replace`. This prevents partial writes.
- The three-way merge in `json_tool.py` (`settings-merge` command) preserves user modifications made between install and uninstall by computing what the tool added (post vs base), removing those from current, then restoring anything from base that was also removed by the user.
- `json_tool.py` uses only Python standard library -- no external dependencies.
- State files, backups, and snapshots get `chmod 700/600` via `umask 077` in the main script and explicit `os.chmod` in the Python tool.
- The `CM_` variable naming convention applies across all shell modules with no namespace collisions.
