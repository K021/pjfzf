#!/usr/bin/env zsh
# test_pj.zsh - Tests for pj project navigator
# Usage: zsh tests/test_pj.zsh

# --- Test framework -----------------------------------------------------------

_test_count=0
_test_pass=0
_test_fail=0

_inc() { : $(( $1 = ${(P)1} + 1 )) }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  _inc _test_count
  if [[ "$expected" == "$actual" ]]; then
    _inc _test_pass
    echo "  PASS: $desc"
  else
    _inc _test_fail
    echo "  FAIL: $desc"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  _inc _test_count
  if [[ "$haystack" == *"$needle"* ]]; then
    _inc _test_pass
    echo "  PASS: $desc"
  else
    _inc _test_fail
    echo "  FAIL: $desc"
    echo "    expected to contain: '$needle'"
    echo "    actual: '$haystack'"
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  _inc _test_count
  if [[ "$haystack" != *"$needle"* ]]; then
    _inc _test_pass
    echo "  PASS: $desc"
  else
    _inc _test_fail
    echo "  FAIL: $desc"
    echo "    expected NOT to contain: '$needle'"
  fi
}

assert_path_exists() {
  local desc="$1" filepath="$2"
  _inc _test_count
  if [[ -e "$filepath" ]]; then
    _inc _test_pass
    echo "  PASS: $desc"
  else
    _inc _test_fail
    echo "  FAIL: $desc (path not found: $filepath)"
  fi
}

assert_return() {
  local desc="$1" expected="$2" actual="$3"
  _inc _test_count
  if [[ "$expected" == "$actual" ]]; then
    _inc _test_pass
    echo "  PASS: $desc"
  else
    _inc _test_fail
    echo "  FAIL: $desc (expected return $expected, got $actual)"
  fi
}

# --- Setup / Teardown ---------------------------------------------------------

TEST_TMPDIR=$(mktemp -d)
TEST_CONFIG_DIR="${TEST_TMPDIR}/config/pj"
TEST_PROJECTS_DIR="${TEST_TMPDIR}/projects"

setup() {
  # Recreate temp dir if torn down
  if [[ ! -d "$TEST_TMPDIR" ]]; then
    TEST_TMPDIR=$(mktemp -d)
    TEST_CONFIG_DIR="${TEST_TMPDIR}/config/pj"
    TEST_PROJECTS_DIR="${TEST_TMPDIR}/projects"
  fi

  # Create test project directories
  mkdir -p "${TEST_PROJECTS_DIR}/alpha"
  mkdir -p "${TEST_PROJECTS_DIR}/beta"
  mkdir -p "${TEST_PROJECTS_DIR}/gamma-project"
  mkdir -p "${TEST_PROJECTS_DIR}/delta-sync"
  mkdir -p "${TEST_TMPDIR}/work/project-x"
  mkdir -p "${TEST_TMPDIR}/work/project-y"

  # Override config paths
  _PJ_CONFIG_DIR="$TEST_CONFIG_DIR"
  _PJ_CONFIG_FILE="${TEST_CONFIG_DIR}/config"
  _PJ_HISTORY_FILE="${TEST_CONFIG_DIR}/history"

  # Clean config dir
  rm -rf "$TEST_CONFIG_DIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# --- Source the module --------------------------------------------------------

SCRIPT_DIR="${0:A:h}/.."
source "${SCRIPT_DIR}/pj.zsh"

# --- Tests --------------------------------------------------------------------

echo "=== Test: _pj_init ==="
setup
_pj_init
assert_path_exists "config dir created" "${TEST_CONFIG_DIR}"
assert_path_exists "config file created" "${_PJ_CONFIG_FILE}"
assert_path_exists "history file created" "${_PJ_HISTORY_FILE}"
local config_content=$(cat "$_PJ_CONFIG_FILE")
assert_contains "default config has ~/projects" "$HOME/projects" "$config_content"

echo ""
echo "=== Test: _pj_list ==="
setup
_pj_init
echo "${TEST_PROJECTS_DIR}" > "$_PJ_CONFIG_FILE"
local list_output=$(_pj_list)
assert_contains "list includes alpha" "${TEST_PROJECTS_DIR}/alpha" "$list_output"
assert_contains "list includes beta" "${TEST_PROJECTS_DIR}/beta" "$list_output"
assert_contains "list includes gamma-project" "${TEST_PROJECTS_DIR}/gamma-project" "$list_output"
assert_contains "list includes delta-sync" "${TEST_PROJECTS_DIR}/delta-sync" "$list_output"

echo ""
echo "=== Test: _pj_list with multiple base dirs ==="
setup
_pj_init
printf '%s\n' "${TEST_PROJECTS_DIR}" "${TEST_TMPDIR}/work" > "$_PJ_CONFIG_FILE"
list_output=$(_pj_list)
assert_contains "list includes projects/alpha" "${TEST_PROJECTS_DIR}/alpha" "$list_output"
assert_contains "list includes work/project-x" "${TEST_TMPDIR}/work/project-x" "$list_output"

echo ""
echo "=== Test: _pj_list ignores comments and blank lines ==="
setup
_pj_init
printf '%s\n' "# this is a comment" "" "${TEST_PROJECTS_DIR}" > "$_PJ_CONFIG_FILE"
list_output=$(_pj_list)
assert_contains "list includes alpha" "${TEST_PROJECTS_DIR}/alpha" "$list_output"

echo ""
echo "=== Test: _pj_score ==="
local now=$(date +%s)
local score=$(_pj_score $(( now - 1800 )) 5)
assert_eq "score within 1h: 5*16=80" "80" "$score"
score=$(_pj_score $(( now - 43200 )) 3)
assert_eq "score within 1d: 3*8=24" "24" "$score"
score=$(_pj_score $(( now - 259200 )) 10)
assert_eq "score within 1w: 10*4=40" "40" "$score"
score=$(_pj_score $(( now - 1209600 )) 7)
assert_eq "score within 1m: 7*2=14" "14" "$score"
score=$(_pj_score $(( now - 5000000 )) 20)
assert_eq "score older: 20*1=20" "20" "$score"

echo ""
echo "=== Test: _pj_update ==="
setup
_pj_init
echo "${TEST_PROJECTS_DIR}" > "$_PJ_CONFIG_FILE"

_pj_update "${TEST_PROJECTS_DIR}/alpha"
local hist=$(cat "$_PJ_HISTORY_FILE")
assert_contains "history has alpha" "alpha|${TEST_PROJECTS_DIR}/alpha" "$hist"
assert_contains "history count is 1" "|1" "$hist"

_pj_update "${TEST_PROJECTS_DIR}/alpha"
local count_field=$(command grep "alpha" "$_PJ_HISTORY_FILE" | cut -d'|' -f4)
assert_eq "history count incremented to 2" "2" "$count_field"

_pj_update "${TEST_PROJECTS_DIR}/beta"
local line_count=$(wc -l < "$_PJ_HISTORY_FILE" | tr -d ' ')
assert_eq "history has 2 entries" "2" "$line_count"

echo ""
echo "=== Test: _pj_sorted ==="
setup
_pj_init
echo "${TEST_PROJECTS_DIR}" > "$_PJ_CONFIG_FILE"

now=$(date +%s)
printf '%s\n' \
  "gamma-project|${TEST_PROJECTS_DIR}/gamma-project|${now}|10" \
  "alpha|${TEST_PROJECTS_DIR}/alpha|$(( now - 100000 ))|2" \
  > "$_PJ_HISTORY_FILE"

local sorted=$(_pj_sorted)
local first_line=$(echo "$sorted" | head -1)
local second_line=$(echo "$sorted" | sed -n '2p')
assert_eq "highest frecency first" "${TEST_PROJECTS_DIR}/gamma-project" "$first_line"
assert_eq "lower frecency second" "${TEST_PROJECTS_DIR}/alpha" "$second_line"

local third_line=$(echo "$sorted" | sed -n '3p')
local fourth_line=$(echo "$sorted" | sed -n '4p')
assert_eq "unscored sorted alpha: beta" "${TEST_PROJECTS_DIR}/beta" "$third_line"
assert_eq "unscored sorted alpha: delta-sync" "${TEST_PROJECTS_DIR}/delta-sync" "$fourth_line"

echo ""
echo "=== Test: _pj_add_base ==="
setup
_pj_init

local add_output=$(_pj_add_base "${TEST_TMPDIR}/work")
local ret=$?
assert_return "add returns 0" 0 $ret
assert_contains "add success message" "added" "$add_output"

local config=$(cat "$_PJ_CONFIG_FILE")
assert_contains "config contains new path" "${TEST_TMPDIR}/work" "$config"

_pj_add_base "${TEST_TMPDIR}/work" 2>/dev/null
ret=$?
assert_return "add duplicate returns 1" 1 $ret

_pj_add_base "/nonexistent/path" 2>/dev/null
ret=$?
assert_return "add nonexistent returns 1" 1 $ret

echo ""
echo "=== Test: _pj_remove_base ==="
setup
_pj_init
printf '%s\n' "$HOME/projects" "${TEST_TMPDIR}/work" > "$_PJ_CONFIG_FILE"

local rm_output=$(_pj_remove_base "${TEST_TMPDIR}/work")
ret=$?
assert_return "remove returns 0" 0 $ret
assert_contains "remove success message" "removed" "$rm_output"

config=$(cat "$_PJ_CONFIG_FILE")
assert_not_contains "removed path not in config" "${TEST_TMPDIR}/work" "$config"

_pj_remove_base "/nonexistent" 2>/dev/null
ret=$?
assert_return "remove nonexistent returns 1" 1 $ret

echo ""
echo "=== Test: _pj_show_config ==="
setup
_pj_init
printf '%s\n' "${TEST_PROJECTS_DIR}" "${TEST_TMPDIR}/work" > "$_PJ_CONFIG_FILE"

local show_output=$(_pj_show_config)
assert_contains "show includes first dir" "${TEST_PROJECTS_DIR}" "$show_output"
assert_contains "show includes second dir" "${TEST_TMPDIR}/work" "$show_output"
assert_contains "show has header" "Base directories" "$show_output"

echo ""
echo "=== Test: _pj_help ==="
local help_output=$(_pj_help)
assert_contains "help shows usage" "Usage:" "$help_output"
assert_contains "help shows add" "pj add" "$help_output"
assert_contains "help shows remove" "pj remove" "$help_output"

echo ""
echo "=== Test: pj subcommands (non-fzf) ==="
setup
_pj_init
echo "${TEST_PROJECTS_DIR}" > "$_PJ_CONFIG_FILE"

local list_out=$(pj list)
assert_contains "pj list shows base dir" "${TEST_PROJECTS_DIR}" "$list_out"

local help_out=$(pj help)
assert_contains "pj help shows usage" "Usage:" "$help_out"

pj add "${TEST_TMPDIR}/work" > /dev/null
config=$(cat "$_PJ_CONFIG_FILE")
assert_contains "pj add works" "${TEST_TMPDIR}/work" "$config"

pj remove "${TEST_TMPDIR}/work" > /dev/null
config=$(cat "$_PJ_CONFIG_FILE")
assert_not_contains "pj remove works" "${TEST_TMPDIR}/work" "$config"

echo ""
echo "=== Test: edge case - nonexistent base dir in config ==="
setup
_pj_init
printf '%s\n' "/nonexistent/dir" "${TEST_PROJECTS_DIR}" > "$_PJ_CONFIG_FILE"

list_output=$(_pj_list)
assert_contains "list still includes valid dirs" "${TEST_PROJECTS_DIR}/alpha" "$list_output"
assert_not_contains "nonexistent dir excluded from list" "/nonexistent/" "$list_output"

echo ""
echo "=== Test: edge case - history with stale entries ==="
setup
_pj_init
echo "${TEST_PROJECTS_DIR}" > "$_PJ_CONFIG_FILE"

now=$(date +%s)
printf '%s\n' \
  "gone-project|/nonexistent/gone-project|${now}|50" \
  "alpha|${TEST_PROJECTS_DIR}/alpha|${now}|5" \
  > "$_PJ_HISTORY_FILE"

sorted=$(_pj_sorted)
assert_not_contains "stale history entry excluded" "/nonexistent/gone-project" "$sorted"
assert_contains "valid history entry present" "${TEST_PROJECTS_DIR}/alpha" "$sorted"

teardown

# --- Summary ------------------------------------------------------------------

echo ""
echo "============================================"
echo "Total: $_test_count  Pass: $_test_pass  Fail: $_test_fail"
echo "============================================"

if (( _test_fail > 0 )); then
  exit 1
else
  echo "All tests passed!"
  exit 0
fi
