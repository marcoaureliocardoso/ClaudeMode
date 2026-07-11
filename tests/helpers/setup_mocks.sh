#!/usr/bin/env bash
set -euo pipefail

setup_test_env() {
  TEST_TMP=$(mktemp -d "${TEST_SUITE_TMP:-/tmp}/claude-mode-test.XXXXXX")
  export TEST_TMP
  export HOME="$TEST_TMP/home"
  export XDG_STATE_HOME="$TEST_TMP/state"
  export MOCK_BIN="$TEST_TMP/mock-bin"
  export MOCK_LOG="$TEST_TMP/mock.log"
  export MOCK_CLAUDE_PLUGINS="$TEST_TMP/plugins.json"
  mkdir -p "$HOME/.claude" "$MOCK_BIN" "$XDG_STATE_HOME"
  printf '[]\n' >"$MOCK_CLAUDE_PLUGINS"
  : >"$MOCK_LOG"
  export PATH="$MOCK_BIN:$ORIGINAL_PATH"
  make_mock_claude
  make_mock_nori
  make_mock_npm
}

teardown_test_env() {
  rm -rf "$TEST_TMP"
}

make_mock_claude() {
  cat >"$MOCK_BIN/claude" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'claude %q\n' "$*" >> "$MOCK_LOG"
if [[ "${1:-}" == "--version" ]]; then echo '2.1.205'; exit 0; fi
[[ "${1:-}" == "plugin" ]] || { echo 'unsupported claude command' >&2; exit 2; }
sub=${2:-}
case "$sub" in
  list)
    cat "$MOCK_CLAUDE_PLUGINS"
    ;;
  install)
    id=$3
    python3 -S - "$MOCK_CLAUDE_PLUGINS" "$id" <<'PY'
import json,sys
p,i=sys.argv[1:]
data=json.load(open(p))
if not any(x.get('id')==i for x in data):
    data.append({'id':i,'name':'superpowers','marketplace':i.split('@',1)[1] if '@' in i else '', 'scope':'local','enabled':True,'version':'6.1.1'})
json.dump(data,open(p,'w'),indent=2)
PY
    ;;
  enable | disable)
    id=$3
    value=true
    [[ "$sub" == disable ]] && value=false
    python3 -S - "$MOCK_CLAUDE_PLUGINS" "$id" "$value" <<'PY'
import json,sys
p,i,v=sys.argv[1:]; v=v=='true'
data=json.load(open(p))
for x in data:
    if x.get('id')==i:
        if x.get('enabled')==v:
            action='enable' if v else 'disable'
            print(f'Plugin "{i}" is already {action}d at local scope',file=sys.stderr)
            raise SystemExit(1)
        x['enabled']=v
        json.dump(data,open(p,'w'),indent=2)
        raise SystemExit(0)
print(f'Plugin "{i}" not found',file=sys.stderr)
raise SystemExit(3)
PY
    ;;
  uninstall)
    id=$3
    python3 -S - "$MOCK_CLAUDE_PLUGINS" "$id" <<'PY'
import json,sys
p,i=sys.argv[1:]
data=[x for x in json.load(open(p)) if x.get('id')!=i]
json.dump(data,open(p,'w'),indent=2)
PY
    ;;
  *) echo "unsupported plugin subcommand: $sub" >&2; exit 2;;
esac
MOCK
  chmod +x "$MOCK_BIN/claude"
}

make_mock_nori() {
  cat >"$MOCK_BIN/nori-skillsets" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'nori %q\n' "$*" >> "$MOCK_LOG"
if [[ "${1:-}" == "--version" ]]; then echo '1.9.0'; exit 0; fi
install_dir=''
args=()
while (($#)); do
  case "$1" in
    --install-dir|-d) install_dir=$2; shift 2;;
    --agent|-a) shift 2;;
    --non-interactive|-n|--silent|-s) shift;;
    *) args+=("$1"); shift;;
  esac
done
set -- "${args[@]}"
cmd=${1:-}
profiles="$HOME/.nori/profiles"
case "$cmd" in
  init)
    mkdir -p "$profiles/personal" "$profiles/public"
    ;;
  download)
    name=${2:?}
    mkdir -p "$profiles/public/$name/skills/example"
    printf '{"name":"%s","version":"1.0.0","type":"skillset"}\n' "$name" > "$profiles/public/$name/nori.json"
    if [[ "${MOCK_NORI_BUGGY_VERSION:-}" == "1" ]]; then
      # Buggy CLAUDE.md with truncation (Bug 1 + Bug 11)
      cat > "$profiles/public/$name/CLAUDE.md" <<'BUGCLAUD'
# BEGIN NORI-AI MANAGED BLOCK
<required>
- *CRITICAL* Add each element of this checklist to your Todo list using TodoWrite. DO NOT BE LAZY.
- Read `{{skills_dir}}/using-skills/SKILL.md`
- Ask me to pick a mode: nori-full-send or nori-copilot.
<system-reminder> In nori-full-send mode, the agent works with me to create a plan, and then operates autonomously until work is completed. </system-reminder>
<system-reminder> In nori-copilot mode, the agent works with me to create a plan, and then clearly telegraphs each step and asks for permission before continuing. </system-reminder>
</required>
# Nori Full-send Mode
<required>
- *CRITICAL* Add each element of this checklist to your Todo list using TodoWrite. DO NOT BE LAZY.
- Use test driven development.
</required>
# Nori Copilot Mode
<required>
- *CRITICAL* Add each element of this checklist to your Todo list using TodoWrite. DO NOT BE LAZY.
<system-reminder> Copilot mode should behave identically to full-send mode, just on your
- Research how to best solve my question WITHOUT making code changes
  - Use subagents to do your deep research. If you have access to the nori-knowledge-researcher subagent, use that one.
</required>
# Tone
Do not be deferential.
# Coding Guidelines
YAGNI.
# Nori Skills System
You have access to the Nori skills system.
# END NORI-AI MANAGED BLOCK
BUGCLAUD
      # Buggy agents
      mkdir -p "$profiles/public/$name/subagents"
      # Bug 2: duplicate step 3
      cat > "$profiles/public/$name/subagents/nori-code-reviewer.md" <<'BUGAGENT'
---
name: nori-code-reviewer
description: Code review agent
tools: Read, Grep, Glob, Bash, TodoWrite
model: inherit
---
You are a code reviewer.
<required>
*CRITICAL* Add the following steps to your Todo list using TodoWrite:
1. Figure out the diff.
2. Review each file that changed.
3. Check if tests can be made less brittle, focusing on end state user behavior
3. Check for bugs
4. Check for refactor opportunities
5. Check for style consistency
6. Do a holistic *behavior* analysis.
7. Compile a summary of suggestions and present them
</required>
BUGAGENT
      # Bug 5: broken recall/memorize refs + Bug 4: skipped step 7 + Bug 9: YAML name mismatch
      cat > "$profiles/public/$name/subagents/paid-nori-knowledge-researcher.md" <<'BUGAGENT'
---
name: nori-knowledge-researcher
description: Research specialist
tools: Read, Grep, Glob, Bash, WebFetch, WebSearch
model: inherit
---
You are a knowledge research specialist.
# Research Budget
**Maximum tool calls: 15**
## Phase 1: Initial Search (3-5 tool calls)
1. **Check for docs.md files** in relevant directories
2. <required>You MUST use the **Recall** skill ({{skills_dir}}/recall/SKILL.md) at least one time.</required>
3. <required>**Fetch complete articles** with `--id` parameter at least THREE times.</required>
4. **Start with the most specific query**
5. **Evaluate results** — stop and report if sufficient
6. **If gaps remain**: Try 1-2 alternative phrasings
8. **Quick assessment**: Can you answer now?
## Phase 2: Targeted Expansion (3-5 tool calls, only if needed)
Only proceed if Phase 1 left critical gaps:
1. **Follow specific references** found in Phase 1
2. **Check related code** using Read/Grep
3. **External lookup** if URLs mentioned
4. **Search again** with different queries
## Capabilities
- **Recall**: Query knowledge base. Read {{skills_dir}}/recall/SKILL.md.
- **Memorize**: Save insights. Read {{skills_dir}}/memorize/SKILL.md.
BUGAGENT
      # Bug 6: nori-sync-docs refs
      cat > "$profiles/public/$name/subagents/nori-initial-documenter.md" <<'BUGAGENT'
---
name: nori-initial-documenter
description: Creates documentation
tools: Read, Grep, Glob, LS, Write, Edit, Bash
model: inherit
---
You are a documenter.
<required>
*CRITICAL* Add the following steps:
# Step 4: Sync Remote docs.md Files
- Check if the nori-sync-docs skill exists at {{skills_dir}}/nori-sync-docs/SKILL.md.
- Read and follow {{skills_dir}}/nori-sync-docs/SKILL.md to sync all noridocs.
</required>
BUGAGENT
      # Bug 6 (second file) + Bug 10: typo
      cat > "$profiles/public/$name/subagents/nori-change-documenter.md" <<'BUGAGENT'
---
name: nori-change-documenter
description: Creates documentation about changes
tools: Read, Grep, Glob, LS, Write, Edit, Bash
model: inherit
---
You are a change documenter.
<required>
*CRITICAL* Add the following steps:
# Step 4: Sync Remote docs.md Files
- Check if the nori-sync-docs skill exists at {{skills_dir}}/nori-sync-docs/SKILL.md.
</required>
## Core Responsibilities
2. **Document Chnages**
BUGAGENT
      # Buggy skills
      mkdir -p "$profiles/public/$name/skills/creating-debug-tests-and-iterating"
      # Bug 3: skipped step 4
      cat > "$profiles/public/$name/skills/creating-debug-tests-and-iterating/SKILL.md" <<'BUGSKILL'
---
name: creating-debug-tests-and-iterating
description: Debug testing skill
---
<required>
*CRITICAL* Add the following steps to your Todo list using TodoWrite:
1. Write a script
2. Check for authentication
3. Follow these steps in a loop until the bug is fixed:
  - Add logs
  - Run debug script
5. Identify and fix the issue
6. Clean up background jobs
7. Make sure other tests pass
</required>
BUGSKILL
      mkdir -p "$profiles/public/$name/skills/finishing-a-development-branch"
      # Bug 7: test-scenario-hygiene
      cat > "$profiles/public/$name/skills/finishing-a-development-branch/SKILL.md" <<'BUGSKILL'
---
name: finishing-a-development-branch
description: Finish development
---
<required>
*CRITICAL* Add the following steps:
1. Verify tests
6. Use nori-code-reviewer subagent
7. Run the test-scenario-hygiene skill in a subagent to do test review
8. Confirm you are not on main
9. Push and create PR
</required>
BUGSKILL
      mkdir -p "$profiles/public/$name/skills/test-driven-development"
      # Bug 8: nori-task-runner
      cat > "$profiles/public/$name/skills/test-driven-development/SKILL.md" <<'BUGSKILL'
---
name: test-driven-development
description: TDD skill
---
<required>
*CRITICAL* Add the following steps:
1. Write failing tests (RED phase)
2. Create a subagent using the nori-task-runner to evaluate test quality.
3. Verify the test fails
4. Write minimal code to pass
5. Verify the test passes
6. Refactor
7. Verify tests still pass
</required>
BUGSKILL
    else
      printf '# Senior SWE\n' > "$profiles/public/$name/CLAUDE.md"
      printf '%s\n' '---' 'name: example' 'description: example' '---' > "$profiles/public/$name/skills/example/SKILL.md"
    fi
    ;;
  list)
    find "$profiles" -mindepth 2 -maxdepth 2 -name nori.json -print 2>/dev/null | sed -E 's#^.*/profiles/##;s#/nori.json$##'
    ;;
  switch)
    name=${2:?}
    [[ -n "$install_dir" ]] || { echo 'missing install dir' >&2; exit 5; }
    if [[ "${MOCK_FAIL_NORI_SWITCH:-}" == "$name" ]]; then
      echo "forced Nori switch failure: $name" >&2
      exit 42
    fi
    src=''
    for candidate in "$profiles/personal/$name" "$profiles/public/$name" "$profiles/$name" "$profiles/$name"; do
      [[ -f "$candidate/nori.json" ]] && { src=$candidate; break; }
    done
    [[ -n "$src" ]] || { echo "profile not found: $name" >&2; exit 6; }
    mkdir -p "$install_dir/.claude"
    rm -rf "$install_dir/.claude/skills" "$install_dir/.claude/agents" "$install_dir/.claude/commands"
    rm -f "$install_dir/.claude/CLAUDE.md"
    rel=${src#"$profiles/"}
    printf '%s\n' "$rel" > "$install_dir/.claude/.nori-managed"
    [[ -f "$src/CLAUDE.md" ]] && cp "$src/CLAUDE.md" "$install_dir/.claude/CLAUDE.md"
    [[ -d "$src/skills" ]] && cp -R "$src/skills" "$install_dir/.claude/skills"
    [[ -d "$src/subagents" ]] && cp -R "$src/subagents" "$install_dir/.claude/agents"
    settings="$HOME/.claude/settings.json"
    [[ -f "$settings.pre-nori" ]] || { [[ -f "$settings" ]] && cp "$settings" "$settings.pre-nori" || true; }
    python3 -S - "$settings" <<'PY'
import json,sys,os
p=sys.argv[1]
try: d=json.load(open(p))
except Exception: d={}
h=d.setdefault('hooks',{})
g=h.setdefault('SessionStart',[])
entry={'matcher':'startup','hooks':[{'type':'command','command':'node /mock/nori-skillsets/update-check.js'}]}
if entry not in g: g.append(entry)
d['includeCoAuthoredBy']=False
os.makedirs(os.path.dirname(p),exist_ok=True)
json.dump(d,open(p,'w'),indent=2)
PY
    ;;
  current)
    [[ -f "$install_dir/.claude/.nori-managed" ]] && cat "$install_dir/.claude/.nori-managed"
    ;;
  clear)
    [[ -n "$install_dir" ]] || exit 5
    rm -rf "$install_dir/.claude/skills" "$install_dir/.claude/agents" "$install_dir/.claude/commands"
    rm -f "$install_dir/.claude/CLAUDE.md" "$install_dir/.claude/.nori-managed"
    if [[ -f "$HOME/.claude/settings.json.pre-nori" ]]; then
      cp "$HOME/.claude/settings.json.pre-nori" "$HOME/.claude/settings.json"
      rm -f "$HOME/.claude/settings.json.pre-nori"
    fi
    ;;
  *) echo "unsupported nori command: $cmd" >&2; exit 2;;
esac
MOCK
  chmod +x "$MOCK_BIN/nori-skillsets"
}

make_mock_npm() {
  cat >"$MOCK_BIN/npm" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'npm %q\n' "$*" >> "$MOCK_LOG"
exit 0
MOCK
  chmod +x "$MOCK_BIN/npm"
}
