# Changelog

## 0.1.1 — 2026-07-10

- ShellCheck linting applied to all scripts (zero warnings).
- Consistent formatting with shfmt (`-i 2 -ci`).
- Added `.editorconfig` for cross-editor consistency.
- `json_tool.py` error messages now include the failing command name.
- Refactored `cm_other_installed_states`: flag-based control flow replaces `raise SystemExit`.
- Removed unused `existing_state` variable in `cm_install`.
- Replaced `A && B || C` pattern with explicit `if/then` in `cm_debug` and `cm_nori_marker`, preserving defensive `|| true` behavior.
- Security fix: `rm` with `${var:?}` guard to prevent accidental `/*` expansion.
- Expanded `.gitignore`: worktrees, shellcheck/shfmt/gh binaries, tar archives.
- Eleven behavioral tests (added `json_tool` error context test with exit code assertion).

## 0.1.0 — 2026-07-10

- Concurrent installation of Nori `senior-swe` and Superpowers.
- Mutually exclusive switching between `senior` and `superpowers`.
- Superpowers plugin restricted to Claude Code `local` scope.
- Empty tool-owned Nori skillset for neutralization.
- Per-project state, lock, dry-run, human/JSON status, and doctor.
- Best-effort rollback.
- Uninstall with preexisting component restoration.
- Three-way merge to preserve user changes in `~/.claude/settings.json`.
- Ten behavioral tests with mocks.
