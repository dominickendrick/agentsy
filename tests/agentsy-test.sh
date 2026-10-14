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

run_tui '\033[B q'
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

for action in setup teardown; do
  run_agentsy "$action"
  assert_failure "rejects a missing $action target"
  for target in unknown plugins; do
    run_agentsy "$action" "$target" extra
    assert_failure "rejects invalid $action arguments '$target extra'"
    assert_output_contains "Usage: agentsy $action plugins" "shows $action usage"
  done
  run_agentsy "$action" unknown
  assert_failure "rejects an unknown $action target"
done

mkdir -p -- "$TEST_DIR/no-copilot"
ln -s -- "$(command -v bash)" "$TEST_DIR/no-copilot/bash"
ln -s -- "$(command -v dirname)" "$TEST_DIR/no-copilot/dirname"
for action in setup teardown; do
  PATH="$TEST_DIR/no-copilot" run_agentsy "$action" plugins
  assert_failure "$action fails without Copilot CLI"
  assert_output_contains "copilot CLI is required but was not found on PATH" "explains the missing Copilot CLI"
done
[ ! -e "$TEST_HOME/copilot.log" ] || fail "missing Copilot causes no CLI calls"
pass "missing Copilot causes no CLI calls"

mkdir -p -- "$TEST_DIR/copilot-bin"
cat >"$TEST_DIR/copilot-bin/copilot" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[ "$PWD" = "$HOME" ] || { printf 'Copilot must run outside the calling project\n' >&2; exit 1; }
printf '<%s>' "$@" >>"$HOME/copilot.log"
printf '\n' >>"$HOME/copilot.log"
if [ -f "$HOME/copilot-fail" ] && [ "$*" = "$(cat "$HOME/copilot-fail")" ]; then
  printf 'Simulated Copilot failure\n' >&2
  exit 1
fi
case "$*" in
  "plugin marketplace list")
    printf 'Included with GitHub Copilot:\n  ◆ awesome-copilot (GitHub: github/awesome-copilot)\n'
    printf 'Registered marketplaces:\n  • agentsy-tools (Local: /other)\n'
    if [ -f "$HOME/marketplace-source" ]; then
      printf '  • agentsy (%s)\n' "$(cat "$HOME/marketplace-source")"
    fi
    ;;
  "plugin marketplace add "*)
    [ "$#" -eq 4 ]
    printf 'Local: %s\n' "$4" >"$HOME/marketplace-source"
    ;;
  "plugin marketplace remove agentsy")
    rm -- "$HOME/marketplace-source"
    ;;
  "plugin list")
    printf 'Installed plugins:\n  • simplify-goal-extra@agentsy (v1.0.0)\n'
    printf '  • simplify-goal@other (v1.0.0)\n'
    if [ -f "$HOME/plugin-installed" ]; then
      printf 'Live Plugins (loaded from a local marketplace directory, never copied):\n'
      printf '  • simplify-goal@agentsy (v1.0.0) (enabled)\n      from /checkout\n'
    fi
    ;;
  "plugin install simplify-goal@agentsy")
    touch -- "$HOME/plugin-installed"
    ;;
  "plugin uninstall simplify-goal@agentsy")
    rm -- "$HOME/plugin-installed"
    ;;
  *)
    printf 'Unexpected Copilot command: %s\n' "$*" >&2
    exit 1
    ;;
esac
STUB
chmod +x -- "$TEST_DIR/copilot-bin/copilot"
PLUGIN_PATH="$TEST_DIR/copilot-bin:$PATH"

assert_no_plugin_changes() {
  if grep -Eq '<(add|install|uninstall|remove)>' "$TEST_HOME/copilot.log"; then
    fail "$1"
  fi
  pass "$1"
}

PATH="$PLUGIN_PATH" run_agentsy setup plugins
assert_success "sets up plugins"
grep -Fxq -- "<plugin><marketplace><add><$ROOT>" "$TEST_HOME/copilot.log" ||
  fail "registers this checkout as the marketplace"
pass "registers this checkout as the marketplace"
grep -Fxq -- '<plugin><install><simplify-goal@agentsy>' "$TEST_HOME/copilot.log" ||
  fail "installs the plugin from agentsy, not a similarly named plugin"
pass "installs the plugin from agentsy, not a similarly named plugin"

: >"$TEST_HOME/copilot.log"
PATH="$PLUGIN_PATH" run_agentsy setup plugins
assert_success "setting up plugins twice is idempotent"
assert_output_contains "already registered" "reports the existing marketplace"
assert_output_contains "already installed" "reports the existing plugin"
assert_no_plugin_changes "repeated setup makes no add or install calls"

: >"$TEST_HOME/copilot.log"
PATH="$PLUGIN_PATH" run_agentsy teardown plugins
assert_success "tears down plugins"
grep -Fxq -- '<plugin><uninstall><simplify-goal@agentsy>' "$TEST_HOME/copilot.log" ||
  fail "uninstalls only the agentsy plugin"
pass "uninstalls only the agentsy plugin"
grep -Fxq -- '<plugin><marketplace><remove><agentsy>' "$TEST_HOME/copilot.log" ||
  fail "removes the agentsy marketplace"
pass "removes the agentsy marketplace"
[[ "$(grep -E '<(uninstall|remove)>' "$TEST_HOME/copilot.log")" == \
  $'<plugin><uninstall><simplify-goal@agentsy>\n<plugin><marketplace><remove><agentsy>' ]] ||
  fail "uninstalls the plugin before removing the marketplace"
pass "uninstalls the plugin before removing the marketplace"
if [ -e "$TEST_HOME/plugin-installed" ] || [ -e "$TEST_HOME/marketplace-source" ]; then
  fail "removes both plugin and marketplace state"
fi
pass "removes both plugin and marketplace state"

: >"$TEST_HOME/copilot.log"
PATH="$PLUGIN_PATH" run_agentsy teardown plugins
assert_success "tearing down plugins twice is idempotent"
assert_output_contains "already uninstalled" "reports the absent plugin"
assert_output_contains "already removed" "reports the absent marketplace"
assert_no_plugin_changes "repeated teardown makes no uninstall or remove calls"

mkdir -p -- "$TEST_DIR/other checkout"
for source in "Local: $TEST_DIR/other checkout" "GitHub: guardian/agentsy"; do
  printf '%s\n' "$source" >"$TEST_HOME/marketplace-source"
  : >"$TEST_HOME/copilot.log"
  PATH="$PLUGIN_PATH" run_agentsy setup plugins
  assert_failure "refuses to install from a foreign marketplace ($source)"
  assert_output_contains "was not registered from this checkout" "explains the setup ownership conflict"
  assert_no_plugin_changes "does not install from a foreign marketplace"
  touch -- "$TEST_HOME/plugin-installed"
  : >"$TEST_HOME/copilot.log"
  PATH="$PLUGIN_PATH" run_agentsy teardown plugins
  assert_failure "refuses to tear down a foreign marketplace ($source)"
  assert_output_contains "was not registered from this checkout" "explains the marketplace ownership conflict"
  assert_no_plugin_changes "preserves the foreign marketplace and its plugin"
done

ln -s -- "$ROOT" "$TEST_DIR/checkout alias"
printf 'Local: %s\n' "$TEST_DIR/checkout alias" >"$TEST_HOME/marketplace-source"
PATH="$PLUGIN_PATH" run_agentsy teardown plugins
assert_success "recognises this checkout through a symlinked path containing spaces"

for command in "plugin marketplace list" "plugin list"; do
  printf '%s\n' "$command" >"$TEST_HOME/copilot-fail"
  for action in setup teardown; do
    : >"$TEST_HOME/copilot.log"
    PATH="$PLUGIN_PATH" run_agentsy "$action" plugins
    assert_failure "$action fails if '$command' fails"
    assert_no_plugin_changes "a list failure causes no plugin changes"
  done
done
rm -- "$TEST_HOME/copilot-fail"

printf 'plugin marketplace add %s\n' "$ROOT" >"$TEST_HOME/copilot-fail"
: >"$TEST_HOME/copilot.log"
PATH="$PLUGIN_PATH" run_agentsy setup plugins
assert_failure "propagates marketplace registration failures"
if grep -Fq -- '<install>' "$TEST_HOME/copilot.log"; then
  fail "does not install a plugin after registration fails"
fi
pass "does not install a plugin after registration fails"

printf 'plugin install simplify-goal@agentsy\n' >"$TEST_HOME/copilot-fail"
PATH="$PLUGIN_PATH" run_agentsy setup plugins
assert_failure "propagates plugin installation failures"
rm -- "$TEST_HOME/copilot-fail"
PATH="$PLUGIN_PATH" run_agentsy setup plugins
assert_success "setup recovers from a failed installation"
printf 'plugin uninstall simplify-goal@agentsy\n' >"$TEST_HOME/copilot-fail"
: >"$TEST_HOME/copilot.log"
PATH="$PLUGIN_PATH" run_agentsy teardown plugins
assert_failure "propagates plugin uninstallation failures"
if grep -Fq -- '<remove>' "$TEST_HOME/copilot.log"; then
  fail "does not remove a marketplace after an uninstall failure"
fi
pass "does not remove a marketplace after an uninstall failure"
printf 'plugin marketplace remove agentsy\n' >"$TEST_HOME/copilot-fail"
PATH="$PLUGIN_PATH" run_agentsy teardown plugins
assert_failure "propagates marketplace removal failures"
rm -- "$TEST_HOME/copilot-fail"
PATH="$PLUGIN_PATH" run_agentsy teardown plugins
assert_success "teardown recovers from a failed removal"

mkdir -p -- "$TEST_DIR/bin"
ln -s -- "$AGENTSY" "$TEST_DIR/bin/agentsy"
AGENTSY="$TEST_DIR/bin/agentsy"
run_agentsy list --type script
assert_success "resolves the repository through an entrypoint symlink"
assert_output_contains "openai-copilot" "discovers features through an entrypoint symlink"

printf '1..%d\n' "$PASSED"
