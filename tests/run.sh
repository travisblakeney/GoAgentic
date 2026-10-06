#!/usr/bin/env bash
# End-to-end tests for scripts/install.sh, verify.sh and audit.sh.
# Uses throwaway workspaces under a temp dir; touches nothing else.
#
#   tests/run.sh
# ok() always succeeds, so `cond && ok … || nok …` is a safe if/else (SC2015);
# single-quoted backticks and $ARGUMENTS are literal text on purpose (SC2016).
# shellcheck disable=SC2015,SC2016
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$ROOT/scripts/install.sh"
VERIFY="$ROOT/scripts/verify.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/agents-tests.XXXXXX")"
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

pass=0; failed=0
ok()   { pass=$((pass + 1)); echo "ok    $*"; }
nok()  { failed=$((failed + 1)); echo "FAIL  $*"; }
expect_ok()   { local d="$1"; shift; if "$@" >"$TMP/out" 2>&1; then ok "$d"; else nok "$d"; sed 's/^/        /' "$TMP/out"; fi; }
expect_fail() { local d="$1"; shift; if "$@" >"$TMP/out" 2>&1; then nok "$d (expected failure)"; sed 's/^/        /' "$TMP/out"; else ok "$d"; fi; }
new_ws() { local w="$TMP/$1"; mkdir -p "$w"; git -C "$w" init -q; echo "$w"; }

ALL=claude,cursor,codex,gemini,opencode,pi
COMMANDS="ask close doctor help init list new next start status wrap"

# --- audit
expect_ok "audit passes on this checkout" "$ROOT/scripts/audit.sh"

# --- fresh install, every harness
W="$(new_ws all)"
expect_ok "install with every harness" "$INSTALL" "$W" --harness "$ALL"
for c in $COMMANDS; do
  [[ -f "$W/.agents/skills/agents-$c/SKILL.md" ]]   || nok "missing .agents/skills/agents-$c"
  [[ -f "$W/.claude/skills/agents-$c/SKILL.md" ]]   || nok "missing .claude/skills/agents-$c"
  [[ -f "$W/.gemini/commands/agents-$c.toml" ]]     || nok "missing gemini wrapper $c"
  [[ -f "$W/.opencode/commands/agents-$c.md" ]]     || nok "missing opencode wrapper $c"
  [[ -f "$W/.pi/prompts/agents-$c.md" ]]            || nok "missing pi wrapper $c"
done
ok "skills and wrappers present for all commands"
for f in .claude/settings.json .cursor/cli.json .codex/config.toml .gemini/settings.json opencode.json; do
  [[ -f "$W/$f" ]] && ok "permission baseline written: $f" || nok "permission baseline missing: $f"
done
[[ ! -w "$W/.agents/agents-framework/agents/CONVENTIONS.md" ]] && ok "managed files are read-only" || nok "managed files are writable"
grep -q 'Read `.agents/skills/agents-start/SKILL.md`' "$W/.gemini/commands/agents-start.toml" && ok "wrappers point inside the workspace" || nok "wrapper path"
if grep -rqE '(/home/|/Users/|'"$ROOT"')' "$W/.agents" "$W/.gemini" "$W/.opencode" "$W/.pi" "$W/.claude/skills"; then nok "installed files contain absolute paths"; else ok "installed files contain no absolute paths"; fi
[[ "$(tr '\n' ' ' < "$W/.agents/agents-framework/harnesses")" == "claude codex cursor gemini opencode pi " ]] && ok "harness list remembered" || nok "harness list: $(cat "$W/.agents/agents-framework/harnesses")"

# --- verify
expect_ok "verify passes after install (pi warning only)" "$VERIFY" "$W"
expect_ok "re-install is idempotent" "$INSTALL" "$W"
expect_ok "verify still passes" "$VERIFY" "$W"

chmod u+w "$W/.agents/skills/agents-wrap/SKILL.md"; echo "git push" >> "$W/.agents/skills/agents-wrap/SKILL.md"
expect_fail "verify detects a modified skill" "$VERIFY" "$W"
grep -q "modified      .agents/skills/agents-wrap/SKILL.md" "$TMP/out" && ok "…and names it" || nok "modified file not named"
"$INSTALL" "$W" >/dev/null
expect_ok "re-install restores it" "$VERIFY" "$W"

echo "extra" > "$W/.agents/agents-framework/agents/reference/extra.md"
expect_fail "verify detects an unexpected file" "$VERIFY" "$W"
"$INSTALL" "$W" >/dev/null
[[ ! -e "$W/.agents/agents-framework/agents/reference/extra.md" ]] && ok "re-install clears unexpected files" || nok "extra file lingered"

rm "$W/.cursor/cli.json"
expect_fail "verify fails when a permission baseline is missing" "$VERIFY" "$W"
"$INSTALL" "$W" >/dev/null
echo '{"permissions":{"allow":["Shell(*)"]}}' > "$W/.cursor/cli.json"
expect_ok "verify only warns when a permission file was changed" "$VERIFY" "$W"
grep -q "WARN  differs       .cursor/cli.json" "$TMP/out" && ok "…and names it" || nok "differing permission file not named"

# --- existing permission files are never overwritten
W2="$(new_ws existing)"
mkdir -p "$W2/.claude"; echo '{"mine": true}' > "$W2/.claude/settings.json"
expect_ok "install into a workspace with its own settings" "$INSTALL" "$W2" --harness claude
[[ "$(cat "$W2/.claude/settings.json")" == '{"mine": true}' ]] && ok "existing settings.json left untouched" || nok "existing settings.json overwritten"
grep -q "EXISTS AND DIFFERS" "$TMP/out" && ok "…and reported for merging" || nok "not reported"
[[ ! -e "$W2/.cursor" && ! -e "$W2/.gemini" ]] && ok "only the chosen harness was set up" || nok "other harness files written"

# --- dry run writes nothing
W3="$(new_ws dry)"
expect_ok "dry run" "$INSTALL" "$W3" --harness cursor --dry-run
[[ -z "$(find "$W3" -mindepth 1 -maxdepth 1 ! -name .git)" ]] && ok "dry run wrote nothing" || nok "dry run wrote: $(ls -A "$W3")"

# --- refusals
W4="$(new_ws symlink)"
mkdir -p "$TMP/elsewhere"; ln -s "$TMP/elsewhere" "$W4/.agents"
expect_fail "refuses to write through a symlinked .agents" "$INSTALL" "$W4" --harness cursor
[[ -z "$(ls -A "$TMP/elsewhere")" ]] && ok "nothing written outside the workspace" || nok "wrote through symlink"
expect_fail "refuses unknown harness" "$INSTALL" "$(new_ws bad)" --harness cursor,evil
expect_fail "refuses a first install with no harness" "$INSTALL" "$(new_ws none)"
expect_fail "refuses a workspace inside the checkout" "$INSTALL" "$ROOT/framework" --harness cursor
expect_fail "verify fails when nothing is installed" "$VERIFY" "$(new_ws empty)" --harness cursor

# --- uninstall
mkdir -p "$W/agents/Cato"; echo keep > "$W/agents/Cato/role.md"
expect_ok "uninstall" "$INSTALL" "$W" --uninstall
[[ ! -e "$W/.agents/agents-framework" && ! -e "$W/.agents/skills/agents-start" && ! -e "$W/.claude/skills/agents-start" && ! -e "$W/.gemini/commands/agents-start.toml" ]] && ok "managed files removed" || nok "managed files remain"
[[ -f "$W/agents/Cato/role.md" && -f "$W/.claude/settings.json" ]] && ok "agent files and permission files kept" || nok "uninstall removed user files"

# --- the installer never writes outside the workspace
HOME_SENTINEL="$TMP/fakehome"; mkdir -p "$HOME_SENTINEL"
W5="$(new_ws home)"
HOME="$HOME_SENTINEL" "$INSTALL" "$W5" --harness "$ALL" >/dev/null
[[ -z "$(ls -A "$HOME_SENTINEL")" ]] && ok "nothing written to \$HOME" || nok "wrote to HOME: $(ls -A "$HOME_SENTINEL")"

echo
echo "$pass passed, $failed failed"
[[ $failed -eq 0 ]]
