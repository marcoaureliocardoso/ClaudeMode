# Claude Mode Manager Design

## Goal

Provide a project-scoped CLI that keeps Nori `senior-swe` and the Claude Code `superpowers` plugin installed concurrently while ensuring only one behavior is active at a time.

## Supported modes

- `senior`: Nori `senior-swe` active; Superpowers installed at Claude Code `local` scope and disabled.
- `superpowers`: a tool-owned empty Nori skillset (`claude-mode-neutral`) active; Superpowers enabled at `local` scope.
- `none`: neither behavior active after uninstall.
- `invalid`: observed configuration does not match a supported mutually-exclusive state.

## Architecture

`bin/claude-mode` is the command dispatcher. Focused Bash libraries handle project resolution, logging and command execution, state, locks, Claude plugin operations, and Nori operations. `lib/json_tool.py` performs safe JSON parsing, plugin inventory normalization, atomic state updates, and three-way restoration of Claude settings.

State is stored below `${XDG_STATE_HOME:-$HOME/.local/state}/claude-mode/<project-hash>/`. The state directory also contains snapshots of `~/.claude/settings.json`, logs, and the per-project lock.

## Safety model

- All Nori operations use an explicit project installation directory and the `claude-code` agent.
- Superpowers is installed only at Claude Code `local` scope.
- Destructive global removal requires `uninstall --purge-global --yes`.
- The script never calls `nori-skillsets factory-reset` and never edits Claude plugin registry files directly.
- User changes to `~/.claude/settings.json` are preserved with a three-way merge using pre-install, post-install, and pre-uninstall snapshots. Conflicting changes are preserved and reported.
- Tool-owned neutral skillsets are deleted only when their manifest still matches the expected content.
- A project lock prevents concurrent mutations.

## External interfaces

Required: Bash 3.2+, Python 3, Claude Code CLI, Git for automatic project discovery. Node/npm is needed only when Nori must be installed.

Commands:

- `install`
- `use senior|superpowers`
- `status [--json]`
- `doctor [--json]`
- `uninstall [--purge-global] [--yes]`
- `help`

Global flags: `--project PATH`, `--allow-non-git`, `--dry-run`, `--verbose`, `--yes`.

## Testing

A dependency-free Bash harness places mock `claude`, `nori-skillsets`, and `npm` executables first in `PATH`. Tests cover installation, idempotency, both switches, invalid simultaneous activation, dry-run behavior, paths with spaces, plugin conflicts, and clean uninstall.
