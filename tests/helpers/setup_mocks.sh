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
  printf '[]\n' > "$MOCK_CLAUDE_PLUGINS"
  : > "$MOCK_LOG"
  export PATH="$MOCK_BIN:$ORIGINAL_PATH"
  make_mock_claude
  make_mock_nori
  make_mock_npm
}

teardown_test_env() {
  rm -rf "$TEST_TMP"
}

make_mock_claude() {
  cat > "$MOCK_BIN/claude" <<'MOCK'
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
  enable|disable)
    id=$3; value=true; [[ "$sub" == disable ]] && value=false
    python3 -S - "$MOCK_CLAUDE_PLUGINS" "$id" "$value" <<'PY'
import json,sys
p,i,v=sys.argv[1:]; v=v=='true'
data=json.load(open(p))
found=False
for x in data:
    if x.get('id')==i:
        x['enabled']=v; found=True
if not found: raise SystemExit(3)
json.dump(data,open(p,'w'),indent=2)
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
  cat > "$MOCK_BIN/nori-skillsets" <<'MOCK'
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
    printf '# Senior SWE\n' > "$profiles/public/$name/CLAUDE.md"
    printf '%s\n' '---' 'name: example' 'description: example' '---' > "$profiles/public/$name/skills/example/SKILL.md"
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
  cat > "$MOCK_BIN/npm" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'npm %q\n' "$*" >> "$MOCK_LOG"
exit 0
MOCK
  chmod +x "$MOCK_BIN/npm"
}
