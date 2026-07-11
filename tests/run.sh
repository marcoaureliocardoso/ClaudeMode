#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$ROOT/bin/claude-mode"
ORIGINAL_PATH=$PATH
TEST_SUITE_TMP=$(mktemp -d)
export CLI ORIGINAL_PATH TEST_SUITE_TMP
trap 'rm -rf "$TEST_SUITE_TMP"' EXIT
# shellcheck source=tests/helpers/testlib.sh
source "$ROOT/tests/helpers/testlib.sh"
# shellcheck source=tests/helpers/setup_mocks.sh
source "$ROOT/tests/helpers/setup_mocks.sh"

plugin_enabled() {
  python3 -S - "$MOCK_CLAUDE_PLUGINS" <<'PY'
import json,sys
xs=json.load(open(sys.argv[1]))
print(str(xs[0]['enabled']).lower() if xs else 'missing')
PY
}

plugin_count() {
  python3 -S - "$MOCK_CLAUDE_PLUGINS" <<'PY'
import json,sys
print(len(json.load(open(sys.argv[1]))))
PY
}

test_install_and_status() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  printf '{"theme":"dark"}\n' >"$HOME/.claude/settings.json"

  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0
  assert_eq false "$(plugin_enabled)"
  assert_file_exists "$project/.claude/.nori-managed"
  assert_contains "$(cat "$project/.claude/.nori-managed")" senior-swe
  assert_file_exists "$HOME/.nori/profiles/personal/claude-mode-neutral/nori.json"

  run_cli --project "$project" --allow-non-git status --json
  assert_status 0
  assert_json "$LAST_OUTPUT" mode senior
  assert_json "$LAST_OUTPUT" plugin.enabled false
  assert_json "$LAST_OUTPUT" installed true
}

test_install_is_idempotent() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0
  assert_eq 1 "$(plugin_count)"
  count=$(grep -c 'claude plugin\\ install' "$MOCK_LOG" || true)
  assert_eq 1 "$count" 'plugin install should run once'
}

test_switches_are_mutually_exclusive() {
  setup_test_env
  project="$TEST_TMP/project with spaces"
  mkdir -p "$project"
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0

  run_cli --project "$project" --allow-non-git use superpowers
  assert_status 0
  assert_eq true "$(plugin_enabled)"
  assert_contains "$(cat "$project/.claude/.nori-managed")" claude-mode-neutral
  run_cli --project "$project" --allow-non-git status --json
  assert_json "$LAST_OUTPUT" mode superpowers

  run_cli --project "$project" --allow-non-git use senior
  assert_status 0
  assert_eq false "$(plugin_enabled)"
  assert_contains "$(cat "$project/.claude/.nori-managed")" senior-swe
}

test_doctor_detects_simultaneous_activation() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0
  claude plugin enable superpowers@claude-plugins-official --scope local

  run_cli --project "$project" --allow-non-git doctor
  [[ "$LAST_STATUS" -ne 0 ]] || fail 'doctor should fail'
  assert_contains "$LAST_OUTPUT" 'simultaneously active'
}

test_conflicting_plugin_installations_are_rejected() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  cat >"$MOCK_CLAUDE_PLUGINS" <<'JSON'
[
  {"id":"superpowers@claude-plugins-official","name":"superpowers","scope":"local","enabled":false},
  {"id":"superpowers@superpowers-marketplace","name":"superpowers","scope":"user","enabled":true}
]
JSON
  run_cli --project "$project" --allow-non-git --yes install
  [[ "$LAST_STATUS" -ne 0 ]] || fail 'install should reject multiple plugin installations'
  assert_contains "$LAST_OUTPUT" 'multiple Superpowers installations'
}

test_dry_run_does_not_mutate() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  run_cli --project "$project" --allow-non-git --dry-run install
  assert_status 0
  assert_eq 0 "$(plugin_count)"
  assert_file_not_exists "$project/.claude/.nori-managed"
  assert_file_not_exists "$XDG_STATE_HOME/claude-mode"
  assert_contains "$LAST_OUTPUT" 'DRY-RUN'
}

test_uninstall_restores_user_settings_and_removes_owned_components() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  printf '{"theme":"dark","editor":{"font":"mono"}}\n' >"$HOME/.claude/settings.json"
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0
  python3 -S - "$HOME/.claude/settings.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d['editor']['size']=14; json.dump(d,open(p,'w'),indent=2)
PY
  run_cli --project "$project" --allow-non-git use superpowers
  assert_status 0

  run_cli --project "$project" --allow-non-git --yes uninstall
  assert_status 0
  assert_eq 0 "$(plugin_count)"
  assert_file_not_exists "$project/.claude/.nori-managed"
  assert_file_not_exists "$HOME/.nori/profiles/personal/claude-mode-neutral"
  settings=$(cat "$HOME/.claude/settings.json")
  assert_json "$settings" theme dark
  assert_json "$settings" editor.font mono
  assert_json "$settings" editor.size 14
  python3 -S - "$HOME/.claude/settings.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
assert 'includeCoAuthoredBy' not in d
assert not any('nori-skillsets' in str(x) for x in d.get('hooks',{}).get('SessionStart',[]))
PY
}

test_status_without_install_reports_none() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  run_cli --project "$project" --allow-non-git status --json
  assert_status 0
  assert_json "$LAST_OUTPUT" mode none
  assert_json "$LAST_OUTPUT" installed false
}

test_failed_switch_rolls_back_to_previous_mode() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0
  export MOCK_FAIL_NORI_SWITCH=claude-mode-neutral

  run_cli --project "$project" --allow-non-git use superpowers
  [[ "$LAST_STATUS" -ne 0 ]] || fail 'switch should fail'
  unset MOCK_FAIL_NORI_SWITCH
  assert_eq false "$(plugin_enabled)"
  assert_contains "$(cat "$project/.claude/.nori-managed")" senior-swe
  run_cli --project "$project" --allow-non-git status --json
  assert_json "$LAST_OUTPUT" mode senior
}

test_preexisting_plugin_is_restored_on_uninstall() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  cat >"$MOCK_CLAUDE_PLUGINS" <<'JSON'
[{"id":"superpowers@claude-plugins-official","name":"superpowers","marketplace":"claude-plugins-official","scope":"local","enabled":true,"version":"6.1.1"}]
JSON
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0
  assert_eq false "$(plugin_enabled)"
  run_cli --project "$project" --allow-non-git --yes uninstall
  assert_status 0
  assert_eq 1 "$(plugin_count)"
  assert_eq true "$(plugin_enabled)"
  run_cli --project "$project" --allow-non-git status --json
  assert_json "$LAST_OUTPUT" installed false
  assert_json "$LAST_OUTPUT" mode none
}

test_json_tool_errors_include_command_context() {
  setup_test_env
  printf '{invalid' >"$TEST_TMP/bad.json"
  set +e
  local out
  out=$(python3 -S "$ROOT/lib/json_tool.py" state-get "$TEST_TMP/bad.json" some.path 2>&1)
  local ec=$?
  set -e
  assert_eq 2 "$ec" "json_tool should exit 2 on parse errors"
  assert_contains "$out" "state-get"
}

test_install_handles_already_disabled_plugin() {
  setup_test_env
  project="$TEST_TMP/project"
  mkdir -p "$project"
  cat >"$MOCK_CLAUDE_PLUGINS" <<'JSON'
[{"id":"superpowers@claude-plugins-official","name":"superpowers","marketplace":"claude-plugins-official","scope":"local","enabled":false,"version":"6.1.1"}]
JSON
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0
  assert_eq false "$(plugin_enabled)"
  assert_eq 1 "$(plugin_count)"
  run_cli --project "$project" --allow-non-git status --json
  assert_json "$LAST_OUTPUT" mode senior
}

test_patches_fix_all_known_bugs() {
  setup_test_env
  export MOCK_NORI_BUGGY_VERSION=1
  project="$TEST_TMP/project"
  mkdir -p "$project"
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0

  # Bug 1: CLAUDE.md truncation fixed
  assert_contains "$(cat "$project/.claude/CLAUDE.md")" "just on your terms"
  ! grep -qE 'just on your$' "$project/.claude/CLAUDE.md" || fail 'truncated sentence not fixed in CLAUDE.md'

  # Bug 2: no duplicate step 3 in code-reviewer
  local dup_count
  dup_count=$(grep -c '^3\. ' "$project/.claude/agents/nori-code-reviewer.md" 2>/dev/null || echo 0)
  assert_eq 1 "$dup_count" "should have exactly one step 3 in code-reviewer"

  # Bug 3: no skipped step 4 in creating-debug-tests
  local steps
  steps=$(grep -oP '^\d+\.' "$project/.claude/skills/creating-debug-tests-and-iterating/SKILL.md" 2>/dev/null | sort -n | tr '\n' ' ')
  assert_contains "$steps" "4"

  # Bug 4: no skipped step 7 in knowledge-researcher Phase 1
  ! grep -q '^8\.' "$project/.claude/agents/paid-nori-knowledge-researcher.md" 2>/dev/null || fail 'step 8 not renumbered in knowledge-researcher'

  # Bug 5: no recall/memorize references
  ! grep -q 'recall/SKILL.md\|memorize/SKILL.md' "$project/.claude/agents/paid-nori-knowledge-researcher.md" 2>/dev/null || fail 'recall/memorize references not removed'

  # Bug 6: no nori-sync-docs references
  ! grep -q 'nori-sync-docs' "$project/.claude/agents/nori-initial-documenter.md" 2>/dev/null || fail 'nori-sync-docs ref not removed from initial-documenter'
  ! grep -q 'nori-sync-docs' "$project/.claude/agents/nori-change-documenter.md" 2>/dev/null || fail 'nori-sync-docs ref not removed from change-documenter'

  # Bug 7: no test-scenario-hygiene reference
  ! grep -q 'test-scenario-hygiene' "$project/.claude/skills/finishing-a-development-branch/SKILL.md" 2>/dev/null || fail 'test-scenario-hygiene ref not removed'

  # Bug 8: no nori-task-runner reference
  ! grep -q 'nori-task-runner' "$project/.claude/skills/test-driven-development/SKILL.md" 2>/dev/null || fail 'nori-task-runner ref not removed'

  # Bug 9: YAML name fixed
  grep -q '^name: paid-nori-knowledge-researcher' "$project/.claude/agents/paid-nori-knowledge-researcher.md" 2>/dev/null || fail 'YAML name not fixed'

  # Bug 10: typo fixed
  ! grep -q 'Chnages' "$project/.claude/agents/nori-change-documenter.md" 2>/dev/null || fail 'typo Chnages not fixed'
  grep -q 'Document Changes' "$project/.claude/agents/nori-change-documenter.md" 2>/dev/null || fail 'Document Changes not present after fix'

  # Bug 11: CLAUDE.md references paid-nori-knowledge-researcher
  ! grep -qE '(^|[^-])nori-knowledge-researcher([^-]|$)' "$project/.claude/CLAUDE.md" 2>/dev/null || fail 'knowledge-researcher ref not updated in CLAUDE.md'
}

test_patches_are_idempotent() {
  setup_test_env
  export MOCK_NORI_BUGGY_VERSION=1
  project="$TEST_TMP/project"
  mkdir -p "$project"
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0

  # Capture checksums of ALL patched files after first install
  local checksum1
  checksum1=$(md5sum \
    "$project/.claude/CLAUDE.md" \
    "$project/.claude/agents/nori-code-reviewer.md" \
    "$project/.claude/agents/paid-nori-knowledge-researcher.md" \
    "$project/.claude/agents/nori-initial-documenter.md" \
    "$project/.claude/agents/nori-change-documenter.md" \
    "$project/.claude/skills/creating-debug-tests-and-iterating/SKILL.md" \
    "$project/.claude/skills/finishing-a-development-branch/SKILL.md" \
    "$project/.claude/skills/test-driven-development/SKILL.md" \
    2>/dev/null | sort)

  # Run install again (idempotent)
  run_cli --project "$project" --allow-non-git --yes install
  assert_status 0

  # All file checksums must be unchanged — no double-patching
  local checksum2
  checksum2=$(md5sum \
    "$project/.claude/CLAUDE.md" \
    "$project/.claude/agents/nori-code-reviewer.md" \
    "$project/.claude/agents/paid-nori-knowledge-researcher.md" \
    "$project/.claude/agents/nori-initial-documenter.md" \
    "$project/.claude/agents/nori-change-documenter.md" \
    "$project/.claude/skills/creating-debug-tests-and-iterating/SKILL.md" \
    "$project/.claude/skills/finishing-a-development-branch/SKILL.md" \
    "$project/.claude/skills/test-driven-development/SKILL.md" \
    2>/dev/null | sort)
  assert_eq "$checksum1" "$checksum2" "second install should not modify already-patched files"
}

test_patches_respect_dry_run() {
  setup_test_env
  export MOCK_NORI_BUGGY_VERSION=1
  project="$TEST_TMP/project"
  mkdir -p "$project"
  run_cli --project "$project" --allow-non-git --dry-run install
  assert_status 0
  # In dry-run, no files should be created
  assert_file_not_exists "$project/.claude/CLAUDE.md"
  assert_file_not_exists "$project/.claude/skills"
  assert_file_not_exists "$project/.claude/agents"
}

if [[ "${1:-}" == "--worker" ]]; then
  case_name=${2:?missing test function}
  "$case_name"
  exit 0
fi

CASE_LABELS=(
  install_and_status
  install_is_idempotent
  switches_are_mutually_exclusive
  doctor_detects_simultaneous_activation
  conflicting_plugin_installations_are_rejected
  dry_run_does_not_mutate
  uninstall_restores_user_settings
  status_without_install
  failed_switch_rolls_back
  preexisting_plugin_restored
  json_tool_error_context
  install_already_disabled
  patches_fix_all_known_bugs
  patches_are_idempotent
  patches_respect_dry_run
)
CASE_FUNCTIONS=(
  test_install_and_status
  test_install_is_idempotent
  test_switches_are_mutually_exclusive
  test_doctor_detects_simultaneous_activation
  test_conflicting_plugin_installations_are_rejected
  test_dry_run_does_not_mutate
  test_uninstall_restores_user_settings_and_removes_owned_components
  test_status_without_install_reports_none
  test_failed_switch_rolls_back_to_previous_mode
  test_preexisting_plugin_is_restored_on_uninstall
  test_json_tool_errors_include_command_context
  test_install_handles_already_disabled_plugin
  test_patches_fix_all_known_bugs
  test_patches_are_idempotent
  test_patches_respect_dry_run
)

failures=0
index=0
RESULT_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_SUITE_TMP" "$RESULT_DIR"' EXIT
while [[ $index -lt ${#CASE_FUNCTIONS[@]} ]]; do
  PIDS=()
  FILES=()
  LABELS=()
  slot=0
  while [[ $slot -lt 3 && $index -lt ${#CASE_FUNCTIONS[@]} ]]; do
    result_file="$RESULT_DIR/$index.out"
    bash "$0" --worker "${CASE_FUNCTIONS[$index]}" >"$result_file" 2>&1 &
    PIDS+=("$!")
    FILES+=("$result_file")
    LABELS+=("${CASE_LABELS[$index]}")
    index=$((index + 1))
    slot=$((slot + 1))
  done
  slot=0
  while [[ $slot -lt ${#PIDS[@]} ]]; do
    printf 'TEST %s\n' "${LABELS[$slot]}"
    if wait "${PIDS[$slot]}"; then
      if [[ -s "${FILES[$slot]}" ]]; then cat "${FILES[$slot]}"; fi
      printf '  PASS\n'
    else
      cat "${FILES[$slot]}" >&2
      printf '  FAIL\n' >&2
      failures=$((failures + 1))
    fi
    slot=$((slot + 1))
  done
done
printf '\n%d tests, %d failures\n' "${#CASE_FUNCTIONS[@]}" "$failures"
[[ "$failures" -eq 0 ]]
