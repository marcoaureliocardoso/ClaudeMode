# claude-mode

Per-project mode manager that keeps both installed simultaneously:

- the Nori `senior-swe` skillset;
- the Claude Code `superpowers` plugin.

The tool ensures only one behavior is active at a time.

## Modes

| Mode | Nori | Superpowers |
|---|---|---|
| `senior` | `senior-swe` active | installed, disabled at `local` scope |
| `superpowers` | `claude-mode-neutral` active | enabled at `local` scope |
| `none` | project Nori config removed | tool-created component removed or preexisting state restored |

The `claude-mode-neutral` skillset is empty and exists only to remove `senior-swe` instructions without uninstalling Nori.

## Requirements

- Linux or macOS;
- Bash 3.2 or later;
- Python 3;
- Claude Code with `claude plugin` support;
- Git, unless using `--project` with `--allow-non-git`;
- Node.js/npm when Nori is not yet installed.

Documentation consulted:

- https://code.claude.com/docs/en/plugins-reference
- https://github.com/tilework-tech/nori-skillsets
- https://github.com/obra/superpowers

## Tool Installation

In the extracted directory:

```bash
./install.sh
```

By default, files are copied to:

```text
~/.local/lib/claude-mode
~/.local/bin/claude-mode
```

Ensure `~/.local/bin` is in your `PATH`.

You can also run directly from the repository:

```bash
./bin/claude-mode --help
```

## Project Installation

Run at the project root:

```bash
claude-mode install
```

In a directory without Git:

```bash
claude-mode --project /path/to/project --allow-non-git install
```

The installation:

1. records the original state;
2. installs Nori via npm only when necessary;
3. initializes Nori with the project directory explicitly provided;
4. downloads `senior-swe` when absent;
5. creates the empty `claude-mode-neutral` skillset;
6. installs Superpowers at Claude Code `local` scope;
7. disables Superpowers;
8. activates `senior-swe`;
9. verifies the observed mode.

The operation is idempotent. Repeating `install` does not duplicate the plugin or the neutral skillset.

## Switching

### Activate the senior profile

```bash
claude-mode use senior
```

The order is:

```text
Superpowers OFF → Nori senior-swe
```

### Activate the Superpowers methodology

```bash
claude-mode use superpowers
```

The order is:

```text
Nori claude-mode-neutral → Superpowers ON
```

After any switch, end the current session and start a new Claude Code session. Conversation history may retain instructions that have already entered the context.

## State and Diagnostics

```bash
claude-mode status
claude-mode status --json
claude-mode doctor
claude-mode doctor --json
```

`status` queries the actual state of the Nori marker and `claude plugin list --json`; it does not rely solely on the saved file.

`doctor` returns a non-zero exit code when it finds problems, including:

- more than one Superpowers installation;
- Superpowers outside `local` scope;
- `senior-swe` and Superpowers simultaneously active;
- saved mode diverging from observed mode;
- modified neutral skillset;
- missing tools.

## Dry Run

```bash
claude-mode --dry-run install
claude-mode --dry-run use superpowers
claude-mode --dry-run --yes uninstall
```

Dry-run mode does not create locks, state, or configuration files.

## Clean Uninstall

```bash
claude-mode --yes uninstall
```

Normal uninstall:

- removes Nori project configuration;
- removes `claude-mode-neutral` only when it was created by the tool and remains intact;
- uninstalls Superpowers only when it was installed by the tool;
- restores the enabled/disabled state when the plugin already existed;
- preserves `senior-swe`;
- preserves Nori globally;
- retains state, logs, and backups for audit.

To also remove the global Nori package:

```bash
claude-mode --yes --purge-global uninstall
```

Purge is refused when:

- Nori was not installed by this tool;
- another known project still has `claude-mode` installed.

The tool never runs `nori-skillsets factory-reset claude-code`.

## Persistent State and Backups

State is stored at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/claude-mode/<project-hash>/
```

Key files:

```text
state.json
backups/claude-settings.before.json
backups/claude-settings.after-nori.json
backups/claude-settings.before-uninstall.json
backups/claude-settings.merged.json
backups/settings-conflicts.json
```

JSON writes are atomic and use restrictive permissions.

## `settings.json` Preservation

Nori modifies `~/.claude/settings.json`, even in a project-scoped installation. To prevent Nori's backup mechanism from reverting later changes, `claude-mode` performs a three-way merge:

```text
state before Nori
state immediately after Nori
current state before uninstall
```

User changes to keys untouched by Nori are preserved. In scalar conflicts, the current user value is kept and the path appears in `settings-conflicts.json`.

## Rollback

Mutable operations create a transactional snapshot of `~/.claude/settings.json` and record the previous mode. When an operation fails, the exit handler attempts:

1. restore the settings snapshot;
2. restore the previous Nori skillset;
3. restore the previous plugin state;
4. remove a plugin created during an incomplete install;
5. release the lock.

Rollback is best-effort. After a failure:

```bash
claude-mode doctor
claude-mode status --json
```

## Concurrency

Each project uses a directory-based lock. Locks whose PID is still alive block the operation. Abandoned locks are removed on the next run.

## Safety

- paths are canonicalized;
- `/` and `$HOME` are refused as project roots;
- the plugin is manipulated only through the official Claude Code CLI;
- the internal plugin registry is never edited directly;
- global actions require `--purge-global --yes`;
- multiple Superpowers installations cause an abort, not an arbitrary choice;
- a modified neutral skillset is never automatically deleted;
- path expansions are quoted;
- the script uses `set -Eeuo pipefail` and `umask 077`.

## Development

### Tests

```bash
make test
make verify
```

Tests use fake executables in a temporary `PATH` and do not touch real Claude Code, Nori, or npm installations.

Current behavioral coverage (11 tests):

- initial install;
- idempotency;
- bidirectional switching;
- paths with spaces;
- simultaneous activation detection;
- conflicting multiple installations;
- `--dry-run` without mutations;
- `settings.json` change preservation;
- failed switch rollback;
- preexisting plugin restoration;
- status without install;
- json_tool error context.

### Code Quality

The project enforces:

- **ShellCheck**: zero warnings on all scripts (`shellcheck -x`);
- **shfmt**: consistent formatting (`shfmt -d -i 2 -ci`);
- **Bash syntax**: `bash -n` on all `.sh` files;
- **Python**: `python3 -m py_compile` on `lib/json_tool.py`;
- **EditorConfig**: `.editorconfig` for cross-editor consistency.

## Known Limitations

- The automated suite uses mocks. Run `--dry-run` first, then validate with `doctor` on your real Claude Code and Nori installations.
- The JSON format of `claude plugin list --json` is defensively normalized, but future versions may introduce an incompatible format.
- Nori keeps part of its behavior in global Claude Code configuration; other Nori projects should be considered before a global purge.
- The JSON list merge removes entries added by Nori using structural equality. A manual change within the same entry may be preserved as a conflict.

## License

MIT.
