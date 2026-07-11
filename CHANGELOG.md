# Changelog

## 0.2.0 — 2026-07-11

- **Smart patches**: `lib/patch.sh` applies 11 idempotent fixes for upstream bugs in `senior-swe@1.0.2`.
  - Truncated sentence in Copilot Mode section of CLAUDE.md
  - Duplicate step 3 in nori-code-reviewer checklist
  - Skipped step 4 in creating-debug-tests-and-iterating checklist
  - Skipped step 7 in paid-nori-knowledge-researcher Phase 1 checklist
  - Broken references to nonexistent skills (recall, memorize, nori-sync-docs, test-scenario-hygiene, nori-task-runner)
  - YAML name mismatch in paid-nori-knowledge-researcher
  - Typo "Chnages" in nori-change-documenter
  - Incorrect agent reference in CLAUDE.md
- Patches run during `install` and `use senior`. Each patch has a pattern-detection guard for idempotency and version-awareness.
- **Standalone script** `scripts/nori-patch.sh` applies patches independently of claude-mode.
- Mock Nori extended with `MOCK_NORI_BUGGY_VERSION=1` support and `subagents/` directory copying.
- Four new behavioral tests (patches application, idempotency, dry-run respect, install/uninstall cycle smoke test). Total: 16 tests.
- Improved mock fidelity for paid-nori-knowledge-researcher (realistic headings with `## Phase 1:`, Phase 2 cross-references).
- 11 GitHub issues filed upstream: [#541–#551](https://github.com/tilework-tech/nori-skillsets/issues?q=is%3Aissue+author%3Amarcoaureliocardoso).

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
