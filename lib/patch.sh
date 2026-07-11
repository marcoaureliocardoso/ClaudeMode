#!/usr/bin/env bash

# --- Smart Patches for senior-swe@1.0.2 upstream bugs ---
# Each patch has an idempotency guard: checks if the buggy pattern exists
# before applying. If upstream fixes the bug, the pattern won't match and
# the patch silently skips.

cm_nori_apply_patches() {
  cm_debug 'checking for known upstream bugs in senior-swe files'
  cm_patch_truncated_claude_md
  cm_patch_duplicate_step_reviewer
  cm_patch_skipped_step_debug_tests
  cm_patch_skipped_step_researcher_phase1
  cm_patch_broken_recall_memorize
  cm_patch_broken_sync_docs
  cm_patch_broken_test_scenario_hygiene
  cm_patch_broken_task_runner
  cm_patch_yaml_name_mismatch
  cm_patch_typo_chnages
  cm_patch_wrong_agent_reference
}

# Bug 1: Truncated sentence in CLAUDE.md
cm_patch_truncated_claude_md() {
  local f="$CM_PROJECT/.claude/CLAUDE.md"
  [[ -f "$f" ]] || return 0
  grep -qE 'just on your$' "$f" 2>/dev/null || return 0
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: complete truncated sentence in CLAUDE.md'
    return 0
  fi
  python3 -S - "$f" <<'PY'
import sys
with open(sys.argv[1], 'r') as f:
    content = f.read()
content = content.replace(
    'just on your',
    'just on your terms — the agent telegraphs each step and asks for permission before continuing.'
)
with open(sys.argv[1], 'w') as f:
    f.write(content)
PY
  cm_info 'patched: completed truncated sentence in CLAUDE.md'
}

# Bug 2: Duplicate step 3 in nori-code-reviewer
cm_patch_duplicate_step_reviewer() {
  local f="$CM_PROJECT/.claude/agents/nori-code-reviewer.md"
  [[ -f "$f" ]] || return 0
  grep -q '^3\. Check for bugs' "$f" 2>/dev/null || return 0
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: renumber duplicate step 3 in nori-code-reviewer.md'
    return 0
  fi
  python3 -S - "$f" <<'PY'
import sys, re
with open(sys.argv[1], 'r') as f:
    lines = f.readlines()
fixed = []
found_first_three = False
for line in lines:
    m = re.match(r'^(\d+)\.\s', line)
    if m:
        num = int(m.group(1))
        if num == 3 and not found_first_three:
            found_first_three = True
            fixed.append(line)
        elif num == 3 and found_first_three:
            fixed.append(f"4. {line[m.end():]}")
        elif num >= 4 and found_first_three:
            fixed.append(f"{num + 1}. {line[m.end():]}")
        else:
            fixed.append(line)
    else:
        fixed.append(line)
with open(sys.argv[1], 'w') as f:
    f.writelines(fixed)
PY
  cm_info 'patched: renumbered duplicate step 3 in nori-code-reviewer.md'
}

# Bug 3: Skipped step 4 in creating-debug-tests-and-iterating
cm_patch_skipped_step_debug_tests() {
  local f="$CM_PROJECT/.claude/skills/creating-debug-tests-and-iterating/SKILL.md"
  [[ -f "$f" ]] || return 0
  # Detect: step 5 immediately follows step 3
  python3 -S - "$f" <<'PY' | grep -qF 'gap_detected' || return 0
import sys, re
with open(sys.argv[1]) as f:
    lines = f.readlines()
prev = None
for line in lines:
    m = re.match(r'^(\d+)\.\s', line)
    if m:
        num = int(m.group(1))
        if prev is not None and num == prev + 2:
            print('gap_detected')
            break
        prev = num
PY
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: fix skipped step 4 in creating-debug-tests-and-iterating/SKILL.md'
    return 0
  fi
  python3 -S - "$f" <<'PY'
import sys, re
with open(sys.argv[1], 'r') as f:
    lines = f.readlines()
fixed = []
prev = None
gap_found = False
for line in lines:
    m = re.match(r'^(\d+)\.\s', line)
    if m:
        num = int(m.group(1))
        if prev is not None and num == prev + 2:
            gap_found = True
        if gap_found:
            fixed.append(f"{num - 1}. {line[m.end():]}")
        else:
            fixed.append(line)
        prev = num if not gap_found else prev
    else:
        fixed.append(line)
with open(sys.argv[1], 'w') as f:
    f.writelines(fixed)
PY
  cm_info 'patched: fixed skipped step 4 in creating-debug-tests-and-iterating/SKILL.md'
}

# Bug 4: Skipped step 7 in paid-nori-knowledge-researcher Phase 1
cm_patch_skipped_step_researcher_phase1() {
  local f="$CM_PROJECT/.claude/agents/paid-nori-knowledge-researcher.md"
  [[ -f "$f" ]] || return 0
  # Detect gap in Phase 1 section (between ## Phase 1 heading and next ## heading)
  python3 -S - "$f" <<'PY' | grep -qF 'gap_detected' || return 0
import sys, re
with open(sys.argv[1]) as f:
    lines = f.readlines()
in_section = False
prev = None
for line in lines:
    if re.match(r'^##\s+Phase 1\b', line):
        in_section = True
        prev = None
        continue
    if in_section and re.match(r'^##\s', line):
        break  # next section starts
    m = re.match(r'^(\d+)\.\s', line)
    if m and in_section:
        num = int(m.group(1))
        if prev is not None and num == prev + 2:
            print('gap_detected')
            break
        prev = num
PY
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: fix skipped step 7 in paid-nori-knowledge-researcher Phase 1'
    return 0
  fi
  python3 -S - "$f" <<'PY'
import sys, re
with open(sys.argv[1], 'r') as f:
    lines = f.readlines()

# Find Phase 1 section boundaries
start = None
end = None
for i, line in enumerate(lines):
    if re.match(r'^##\s+Phase 1\b', line):
        start = i
    elif start is not None and re.match(r'^##\s', line):
        end = i
        break
if start is not None and end is None:
    end = len(lines)

if start is not None:
    # Find the gap and fix numbering in Phase 1 section
    gap_at = None
    prev = None
    for i in range(start, end):
        m = re.match(r'^(\d+)\.\s', lines[i])
        if m:
            num = int(m.group(1))
            if prev is not None and num == prev + 2:
                gap_at = i
                break
            prev = num
    if gap_at is not None:
        # Renumber from gap onward: decrement all subsequent step numbers
        offset = 1
        for i in range(gap_at, end):
            m = re.match(r'^(\d+)\.\s', lines[i])
            if m:
                num = int(m.group(1))
                lines[i] = f"{num - offset}. {lines[i][m.end():]}"

with open(sys.argv[1], 'w') as f:
    f.writelines(lines)
PY
  cm_info 'patched: fixed skipped step in paid-nori-knowledge-researcher Phase 1'
}

# Bug 5: Broken references to recall and memorize skills
cm_patch_broken_recall_memorize() {
  local f="$CM_PROJECT/.claude/agents/paid-nori-knowledge-researcher.md"
  [[ -f "$f" ]] || return 0
  grep -qE '(recall|memorize)/SKILL\.md' "$f" 2>/dev/null || return 0
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: remove broken recall/memorize skill references'
    return 0
  fi
  python3 -S - "$f" <<'PY'
import sys, re
with open(sys.argv[1], 'r') as f:
    content = f.read()
# Remove <required> blocks that reference recall or memorize skills
content = re.sub(
    r'<required>.*?(?:recall|memorize)/SKILL\.md.*?</required>',
    '',
    content,
    flags=re.DOTALL
)
# Remove lines referencing recall/memorize paths
lines = content.split('\n')
lines = [l for l in lines if 'recall/SKILL.md' not in l and 'memorize/SKILL.md' not in l]
content = '\n'.join(lines)
# Clean up double blank lines
content = re.sub(r'\n{3,}', '\n\n', content)
with open(sys.argv[1], 'w') as f:
    f.write(content)
PY
  cm_info 'patched: removed broken recall/memorize skill references'
}

# Bug 6: Broken references to nori-sync-docs
cm_patch_broken_sync_docs() {
  local f1="$CM_PROJECT/.claude/agents/nori-initial-documenter.md"
  local f2="$CM_PROJECT/.claude/agents/nori-change-documenter.md"
  for f in "$f1" "$f2"; do
    [[ -f "$f" ]] || continue
    grep -q 'nori-sync-docs' "$f" 2>/dev/null || continue
    if [[ "$CM_DRY_RUN" == 1 ]]; then
      cm_info "DRY-RUN: patch: remove nori-sync-docs step from $(basename "$f")"
      continue
    fi
    python3 -S - "$f" <<'PY'
import sys
with open(sys.argv[1], 'r') as f:
    content = f.read()
# Remove the Step 4 section referencing nori-sync-docs
import re
content = re.sub(r'# Step 4: Sync Remote.*?nori-sync-docs[^.]*\.\n?', '', content, flags=re.DOTALL)
# Remove any remaining nori-sync-docs references
lines = content.split('\n')
lines = [l for l in lines if 'nori-sync-docs' not in l]
content = '\n'.join(lines)
# Clean up triple+ blank lines
content = re.sub(r'\n{3,}', '\n\n', content)
with open(sys.argv[1], 'w') as f:
    f.write(content)
PY
    cm_info "patched: removed nori-sync-docs step from $(basename "$f")"
  done
}

# Bug 7: Broken reference to test-scenario-hygiene
cm_patch_broken_test_scenario_hygiene() {
  local f="$CM_PROJECT/.claude/skills/finishing-a-development-branch/SKILL.md"
  [[ -f "$f" ]] || return 0
  grep -q 'test-scenario-hygiene' "$f" 2>/dev/null || return 0
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: remove test-scenario-hygiene reference'
    return 0
  fi
  python3 -S - "$f" <<'PY'
import sys, re
with open(sys.argv[1], 'r') as f:
    lines = f.readlines()
# Remove lines referencing test-scenario-hygiene, and renumber subsequent steps
fixed = []
offset = 0
for line in lines:
    if 'test-scenario-hygiene' in line:
        offset = offset + 1
        continue
    if offset:
        m = re.match(r'^(\d+)\.\s', line)
        if m:
            num = int(m.group(1))
            fixed.append(f"{num - offset}. {line[m.end():]}")
        else:
            fixed.append(line)
    else:
        fixed.append(line)
with open(sys.argv[1], 'w') as f:
    f.writelines(fixed)
PY
  cm_info 'patched: removed test-scenario-hygiene reference'
}

# Bug 8: Broken reference to nori-task-runner
cm_patch_broken_task_runner() {
  local f="$CM_PROJECT/.claude/skills/test-driven-development/SKILL.md"
  [[ -f "$f" ]] || return 0
  grep -q 'nori-task-runner' "$f" 2>/dev/null || return 0
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: remove nori-task-runner reference'
    return 0
  fi
  python3 -S - "$f" <<'PY'
import sys, re
with open(sys.argv[1], 'r') as f:
    lines = f.readlines()
# Remove the line referencing nori-task-runner, renumber subsequent steps
fixed = []
offset = 0
for line in lines:
    if 'nori-task-runner' in line:
        offset = offset + 1
        continue
    if offset:
        m = re.match(r'^(\d+)\.\s', line)
        if m:
            num = int(m.group(1))
            fixed.append(f"{num - offset}. {line[m.end():]}")
        else:
            fixed.append(line)
    else:
        fixed.append(line)
with open(sys.argv[1], 'w') as f:
    f.writelines(fixed)
PY
  cm_info 'patched: removed nori-task-runner reference'
}

# Bug 9: YAML name mismatch (nori-knowledge-researcher -> paid-nori-knowledge-researcher)
cm_patch_yaml_name_mismatch() {
  local f="$CM_PROJECT/.claude/agents/paid-nori-knowledge-researcher.md"
  [[ -f "$f" ]] || return 0
  grep -q '^name: nori-knowledge-researcher' "$f" 2>/dev/null || return 0
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: fix YAML name mismatch in paid-nori-knowledge-researcher.md'
    return 0
  fi
  sed -i 's/^name: nori-knowledge-researcher/name: paid-nori-knowledge-researcher/' "$f"
  cm_info 'patched: fixed YAML name mismatch in paid-nori-knowledge-researcher.md'
}

# Bug 10: Typo "Chnages" in nori-change-documenter
cm_patch_typo_chnages() {
  local f="$CM_PROJECT/.claude/agents/nori-change-documenter.md"
  [[ -f "$f" ]] || return 0
  grep -q 'Chnages' "$f" 2>/dev/null || return 0
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: fix typo in nori-change-documenter.md'
    return 0
  fi
  sed -i 's/Chnages/Changes/g' "$f"
  cm_info 'patched: fixed typo in nori-change-documenter.md'
}

# Bug 11: CLAUDE.md references nori-knowledge-researcher (missing paid- prefix)
cm_patch_wrong_agent_reference() {
  local f="$CM_PROJECT/.claude/CLAUDE.md"
  [[ -f "$f" ]] || return 0
  # Only fix if bare nori-knowledge-researcher appears without paid- prefix.
  # After patching, only paid-nori-knowledge-researcher exists, so this guard
  # prevents double-prefixing (paid-paid-nori-knowledge-researcher).
  if ! grep -q 'nori-knowledge-researcher' "$f" 2>/dev/null; then
    return 0
  fi
  # Check if any occurrence is NOT already prefixed with paid-
  grep -qE '(^|[^-])nori-knowledge-researcher' "$f" 2>/dev/null || return 0
  if [[ "$CM_DRY_RUN" == 1 ]]; then
    cm_info 'DRY-RUN: patch: fix knowledge-researcher reference in CLAUDE.md'
    return 0
  fi
  sed -i 's/\(^\|[^-]\)nori-knowledge-researcher\b/\1paid-nori-knowledge-researcher/g' "$f"
  cm_info 'patched: fixed knowledge-researcher reference in CLAUDE.md'
}
