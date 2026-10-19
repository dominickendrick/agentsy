#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
AGENTSY="$ROOT/agentsy"
TEST_DIR=$(mktemp -d)
TEST_HOME="$TEST_DIR/home"
OUTPUT=""
STATUS=0
PASSED=0

cleanup() {
  rm -rf -- "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p -- "$TEST_HOME"

run_agentsy() {
  set +e
  OUTPUT=$(HOME="$TEST_HOME" "$AGENTSY" "$@" </dev/null 2>&1)
  STATUS=$?
  set -e
}

run_tui() {
  local input="$1"

  set +e
  OUTPUT=$(printf '%b' "$input" | HOME="$TEST_HOME" script -qfec "$AGENTSY" /dev/null 2>&1)
  STATUS=$?
  set -e
}

pass() {
  PASSED=$((PASSED + 1))
  printf 'ok %d - %s\n' "$PASSED" "$1"
}

fail() {
  printf 'not ok %d - %s\n%s\n' "$((PASSED + 1))" "$1" "$OUTPUT" >&2
  exit 1
}

assert_success() {
  local description="$1"
  [ "$STATUS" -eq 0 ] || fail "$description"
  pass "$description"
}

assert_failure() {
  local description="$1"
  [ "$STATUS" -ne 0 ] || fail "$description"
  pass "$description"
}

assert_output_contains() {
  local expected="$1"
  local description="$2"
  [[ "$OUTPUT" == *"$expected"* ]] || fail "$description"
  pass "$description"
}

run_agentsy list
assert_success "lists all features"
assert_output_contains "openai-copilot" "lists the script"
assert_output_contains "writing-style.instructions.md" "lists the instructions"

run_agentsy list --type instructions
assert_success "accepts a plural type filter"
assert_output_contains "writing-style.instructions.md" "lists filtered instructions"
[[ "$OUTPUT" != *"openai-copilot"* ]] || fail "excludes scripts from instructions output"
pass "excludes scripts from instructions output"

run_agentsy list --type instruction
assert_failure "rejects the singular instructions type"

run_agentsy enable script openai-copilot
assert_success "enables a script"
[ "$(readlink -- "$TEST_HOME/.local/bin/openai-copilot")" = "$ROOT/scripts/openai-copilot" ] ||
  fail "links a script into the local bin directory"
pass "links a script into the local bin directory"

run_agentsy enable scripts openai-copilot
assert_success "enabling an existing feature is idempotent"

set +e
OUTPUT=$(HOME="$TEST_HOME" "$TEST_HOME/.local/bin/openai-copilot" gpt-5.6-sol 2>&1)
STATUS=$?
set -e
assert_failure "the enabled script executes through its symlink"
assert_output_contains "OPENAI_API_KEY is not set" "the enabled script loads its repository libraries"

run_agentsy enable instructions writing-style.instructions.md
assert_success "enables instructions"
[[ "$(readlink -- "$TEST_HOME/.copilot/instructions/writing-style.instructions.md")" == "$ROOT/instructions/writing-style.instructions.md" ]] ||
  fail "links instructions into the Copilot directory"
pass "links instructions into the Copilot directory"

run_agentsy disable instructions writing-style.instructions.md
assert_success "disables instructions before a conflict test"
printf 'keep me\n' >"$TEST_HOME/.copilot/instructions/writing-style.instructions.md"
run_agentsy enable instructions writing-style.instructions.md
assert_failure "refuses to replace existing instructions"
assert_output_contains "An instruction with this name already exists at '$TEST_HOME/.copilot/instructions/writing-style.instructions.md'" \
  "explains the instruction name conflict"
rm -- "$TEST_HOME/.copilot/instructions/writing-style.instructions.md"
run_agentsy enable instructions writing-style.instructions.md
assert_success "enables instructions after the conflict is removed"

run_agentsy list --type script
assert_output_contains "enabled" "shows enabled status"

run_agentsy disable script openai-copilot
assert_success "disables a script"
[ ! -e "$TEST_HOME/.local/bin/openai-copilot" ] ||
  fail "removes the Agentsy script link"
pass "removes the Agentsy script link"

run_agentsy disable script openai-copilot
assert_success "disabling an absent feature is idempotent"

printf 'keep me\n' >"$TEST_HOME/.local/bin/openai-copilot"
run_agentsy enable script openai-copilot
assert_failure "refuses to replace a regular file"
assert_output_contains "A script with this name already exists at '$TEST_HOME/.local/bin/openai-copilot'" \
  "explains the script name conflict"
[ "$(cat "$TEST_HOME/.local/bin/openai-copilot")" = "keep me" ] ||
  fail "preserves a conflicting regular file"
pass "preserves a conflicting regular file"
rm -- "$TEST_HOME/.local/bin/openai-copilot"

ln -s -- /tmp/not-agentsy "$TEST_HOME/.local/bin/openai-copilot"
run_agentsy disable script openai-copilot
assert_failure "refuses to remove a foreign symlink"
assert_output_contains "was not enabled by Agentsy and cannot be disabled" \
  "explains why a foreign script cannot be disabled"
[ "$(readlink -- "$TEST_HOME/.local/bin/openai-copilot")" = "/tmp/not-agentsy" ] ||
  fail "preserves a foreign symlink"
pass "preserves a foreign symlink"
rm -- "$TEST_HOME/.local/bin/openai-copilot"

run_agentsy enable skill example
assert_failure "rejects an unsupported feature type"
assert_output_contains "Unsupported feature type" "explains an unsupported type"

run_agentsy enable script missing
assert_failure "rejects an unknown feature"

run_agentsy
assert_success "shows help instead of prompting without a terminal"
assert_output_contains "Usage:" "non-interactive help includes usage"

run_tui ' q'
assert_success "runs the interactive feature manager"
assert_output_contains "Agentsy features" "opens on the feature list"
[ "$(readlink -- "$TEST_HOME/.local/bin/openai-copilot")" = "$ROOT/scripts/openai-copilot" ] ||
  fail "Space enables the selected feature"
pass "Space enables the selected feature"
assert_output_contains $'\033[?1049l' "restores the terminal screen on exit"

run_tui '\033[B\033[B\033[B q'
assert_success "accepts arrow-key navigation"
[ ! -e "$TEST_HOME/.copilot/instructions/writing-style.instructions.md" ] ||
  fail "Space disables the feature selected with an arrow key"
pass "Space disables the feature selected with an arrow key"

mkdir -p -- "$TEST_HOME/.local/bin"
set +e
OUTPUT=$(HOME="$TEST_HOME" PATH="/usr/bin:/bin" "$AGENTSY" install </dev/null 2>&1)
STATUS=$?
set -e
assert_success "installs the entry point"
[ "$(readlink -- "$TEST_HOME/.local/bin/agentsy")" = "$ROOT/agentsy" ] ||
  fail "links the entry point into the local bin directory"
pass "links the entry point into the local bin directory"
assert_output_contains "is not on your PATH" "warns when the local bin directory is not on PATH"

set +e
OUTPUT=$(HOME="$TEST_HOME" PATH="$TEST_HOME/.local/bin:/usr/bin:/bin" "$TEST_HOME/.local/bin/agentsy" install </dev/null 2>&1)
STATUS=$?
set -e
assert_success "installing through the installed link is idempotent"
assert_output_contains "already installed" "recognises an existing installation"
[[ "$OUTPUT" != *"is not on your PATH"* ]] || fail "does not warn when the local bin directory is on PATH"
pass "does not warn when the local bin directory is on PATH"

set +e
OUTPUT=$(HOME="$TEST_HOME" "$TEST_HOME/.local/bin/agentsy" list --type script </dev/null 2>&1)
STATUS=$?
set -e
assert_success "the installed entry point runs"
assert_output_contains "openai-copilot" "the installed entry point finds its checkout"

run_agentsy uninstall
assert_success "uninstalls the entry point"
if [ -e "$TEST_HOME/.local/bin/agentsy" ] || [ -L "$TEST_HOME/.local/bin/agentsy" ]; then
  fail "removes the entry point link"
fi
pass "removes the entry point link"

run_agentsy uninstall
assert_success "uninstalling an absent entry point is idempotent"
assert_output_contains "already uninstalled" "explains that the entry point is already uninstalled"

printf 'keep me\n' >"$TEST_HOME/.local/bin/agentsy"
run_agentsy install
assert_failure "refuses to replace an existing agentsy file"
assert_output_contains "A command named agentsy already exists at '$TEST_HOME/.local/bin/agentsy'" \
  "explains the entry point conflict"
[ "$(cat "$TEST_HOME/.local/bin/agentsy")" = "keep me" ] ||
  fail "preserves a conflicting agentsy file"
pass "preserves a conflicting agentsy file"
rm -- "$TEST_HOME/.local/bin/agentsy"

ln -s -- /tmp/not-agentsy "$TEST_HOME/.local/bin/agentsy"
run_agentsy install
assert_failure "refuses to replace a foreign agentsy symlink"
run_agentsy uninstall
assert_failure "refuses to uninstall a foreign agentsy symlink"
assert_output_contains "was not installed from this checkout" "explains why a foreign entry point cannot be uninstalled"
[ "$(readlink -- "$TEST_HOME/.local/bin/agentsy")" = "/tmp/not-agentsy" ] ||
  fail "preserves a foreign agentsy symlink"
pass "preserves a foreign agentsy symlink"
rm -- "$TEST_HOME/.local/bin/agentsy"

run_agentsy install extra
assert_failure "rejects install arguments"

mkdir -p -- "$TEST_DIR/bin"
ln -s -- "$AGENTSY" "$TEST_DIR/bin/agentsy"
AGENTSY="$TEST_DIR/bin/agentsy"
run_agentsy list --type script
assert_success "resolves the repository through an entrypoint symlink"
assert_output_contains "openai-copilot" "discovers features through an entrypoint symlink"

printf '1..%d\n' "$PASSED"
