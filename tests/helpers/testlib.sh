#!/usr/bin/env bash
set -u

TESTS_RUN=0
TESTS_FAILED=0

fail() {
  printf '  FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected=$1 actual=$2 message=${3:-}
  [[ "$actual" == "$expected" ]] || fail "${message:-values differ}: expected=[$expected] actual=[$actual]"
}

assert_status() {
  assert_eq "$1" "$LAST_STATUS" "unexpected exit status; output: $LAST_OUTPUT"
}

assert_contains() {
  local haystack=$1 needle=$2
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain [$needle], got: $haystack"
}

assert_file_exists() {
  [[ -f "$1" ]] || fail "expected file to exist: $1"
}

assert_file_not_exists() {
  [[ ! -e "$1" ]] || fail "expected path not to exist: $1"
}

assert_json() {
  local json=$1 expr=$2 expected=$3
  local actual
  actual=$(JSON_INPUT="$json" EXPR="$expr" python3 -S - <<'PY'
import json, os
obj=json.loads(os.environ['JSON_INPUT'])
cur=obj
for part in os.environ['EXPR'].split('.'):
    if part:
        cur=cur[int(part)] if isinstance(cur,list) else cur[part]
if isinstance(cur,bool): print(str(cur).lower())
elif cur is None: print('null')
else: print(cur)
PY
) || return 1
  assert_eq "$expected" "$actual" "JSON expression $expr"
}

run_cli() {
  set +e
  LAST_OUTPUT=$("$CLI" "$@" 2>&1)
  LAST_STATUS=$?
  set -e
}

run_test() {
  local name=$1
  shift
  TESTS_RUN=$((TESTS_RUN + 1))
  printf 'TEST %s\n' "$name"
  if ( set -e; "$@" ); then
    printf '  PASS\n'
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  if [[ -n "${TEST_SUITE_TMP:-}" && -d "$TEST_SUITE_TMP" ]]; then
    rm -rf "$TEST_SUITE_TMP"/*
  fi
}

finish_tests() {
  printf '\n%d tests, %d failures\n' "$TESTS_RUN" "$TESTS_FAILED"
  [[ "$TESTS_FAILED" -eq 0 ]]
}
