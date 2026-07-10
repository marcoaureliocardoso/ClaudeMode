# Claude Mode Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a safe project-scoped mode switcher for Nori `senior-swe` and the Claude Code Superpowers plugin.

**Architecture:** A Bash CLI delegates JSON handling to a small Python standard-library helper. External tools are wrapped behind focused libraries and tested using PATH-based mocks.

**Tech Stack:** Bash 3.2+, Python 3 standard library, Git, Claude Code CLI, Nori Skillsets CLI.

## Global Constraints

- Superpowers must use Claude Code `local` scope.
- Nori must always receive an explicit project install directory.
- Only one behavior may be active at a time.
- Never call Nori `factory-reset` or directly edit Claude's plugin registry.
- All mutations must be lock-protected and idempotent.

---

### Task 1: Test harness and expected CLI behavior

**Files:**
- Create: `tests/run.sh`
- Create: `tests/helpers/testlib.sh`
- Create: `tests/helpers/setup_mocks.sh`

**Interfaces:**
- Produces: isolated `$HOME`, `$PATH`, project directory, and mock state files for every test.

- [ ] Write tests for install, status, switch, doctor, dry-run, conflicts, and uninstall.
- [ ] Run `bash tests/run.sh` and verify failure because `bin/claude-mode` does not exist.

### Task 2: Common, lock, and JSON foundations

**Files:**
- Create: `lib/common.sh`
- Create: `lib/lock.sh`
- Create: `lib/state.sh`
- Create: `lib/json_tool.py`

**Interfaces:**
- Produces: project discovery, atomic state operations, portable hashing, lock acquisition, plugin JSON normalization, and settings restoration.

- [ ] Implement the minimum functions required by the first tests.
- [ ] Run focused tests and retain the first failing behavior for the next task.

### Task 3: Claude Code plugin adapter

**Files:**
- Create: `lib/claude_plugin.sh`

**Interfaces:**
- Produces: `cm_plugin_detect`, `cm_plugin_install`, `cm_plugin_enable`, `cm_plugin_disable`, and `cm_plugin_uninstall`.

- [ ] Normalize `claude plugin list --json` and reject multiple Superpowers installations.
- [ ] Use only official plugin subcommands with `--scope local`.
- [ ] Run plugin-focused tests.

### Task 4: Nori adapter and neutral skillset

**Files:**
- Create: `lib/nori.sh`

**Interfaces:**
- Produces: Nori installation checks, skillset discovery, neutral skillset creation, switching, and project cleanup.

- [ ] Create `~/.nori/profiles/personal/claude-mode-neutral/nori.json` atomically with the documented Nori manifest shape.
- [ ] Switch with explicit `--install-dir`, `--agent claude-code`, and non-interactive mode.
- [ ] Refuse to overwrite local Nori changes.
- [ ] Run Nori-focused tests.

### Task 5: CLI orchestration

**Files:**
- Create: `bin/claude-mode`

**Interfaces:**
- Consumes all library interfaces.
- Produces the public CLI and JSON status schema.

- [ ] Implement argument parsing and preflight validation.
- [ ] Implement transactional `install`, mutually-exclusive `use`, `status`, `doctor`, and `uninstall`.
- [ ] Implement state snapshots and rollback traps.
- [ ] Run the full suite.

### Task 6: Documentation and packaging

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `CHANGELOG.md`
- Create: `install.sh`

- [ ] Document commands, files, safety model, recovery, and limitations.
- [ ] Run `bash -n` on every shell file, Python compilation, the full test suite, and ShellCheck/shfmt when installed.
- [ ] Package the repository without `.git`.
