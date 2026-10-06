#!/usr/bin/env bash
# Static audit of this checkout: the invariants that make the framework safe to
# install. Run before tagging a release and in CI. Exit 1 on any violation.
#
#   scripts/audit.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0
bad() { echo "FAIL  $*"; fail=1; }

# 1. The framework that gets installed is data only: markdown, JSON, TOML, VERSION.
while IFS= read -r f; do
  case "$f" in
    *.md|*.json|*.toml|framework/VERSION) ;;
    *) bad "non-data file in framework/: $f" ;;
  esac
done < <(find framework -type f | LC_ALL=C sort)

# 2. Nothing is executable except the reviewed scripts and tests.
while IFS= read -r f; do
  case "$f" in
    ./scripts/*.sh|./tests/*.sh) ;;
    *) bad "executable file outside scripts/ and tests/: $f" ;;
  esac
done < <(find . -path ./.git -prune -o -type f -perm -u+x -print | LC_ALL=C sort)

# 3. No compiled code, build files or package manifests that could pull dependencies.
for pattern in '*.go' 'go.mod' 'go.sum' 'package.json' '*.py' '*.rb' '*.plist' 'Makefile'; do
  while IFS= read -r f; do bad "unexpected file: $f"; done < <(find . -path ./.git -prune -o -name "$pattern" -type f -print)
done

# 4. Skills and references never resolve framework files outside the workspace.
for pattern in 'CLAUDE_PLUGIN_ROOT' 'AGENT_FRAMEWORK_ROOT' 'plugins/cache' 'herdr agent' 'herdr pane' 'harness/install.sh' 'goagentic dash'; do
  if grep -rn --include='*.md' -F "$pattern" framework >/dev/null; then
    bad "framework references '$pattern':"; grep -rn --include='*.md' -F "$pattern" framework | sed 's/^/        /'
  fi
done

# 5. The installer never reaches the network, escalates, or schedules anything.
#    Looks for those commands in command position (line start, after ; & | ( or $( ).
#    Echoed instructions and comments may name them; they are not in command position.
if grep -nE '(^|[;&|(]|\$\()[[:space:]]*(curl|wget|sudo|launchctl|crontab|ssh|scp|nc|npx|brew)([[:space:]]|$)' scripts/install.sh scripts/verify.sh \
   || grep -nE '(^|[;&|(]|\$\()[[:space:]]*git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+(push|pull|fetch|clone|remote)' scripts/install.sh scripts/verify.sh; then
  bad "an installer line above invokes a network, privilege or scheduler command"
fi

# 6. Skill frontmatter is strict-YAML-safe and names match folders.
for d in framework/skills/agents-*/; do
  s="$d/SKILL.md"; n="$(basename "$d")"
  [[ -f "$s" ]] || { bad "missing $s"; continue; }
  [[ "$(sed -n 1p "$s")" == "---" ]] || bad "$s: no frontmatter"
  [[ "$(sed -n 2p "$s")" == "name: $n" ]] || bad "$s: line 2 must be 'name: $n'"
  sed -n 3p "$s" | grep -qE "^description: '.*'$" || bad "$s: description must be one single-quoted line"
  [[ "$(sed -n 4p "$s")" == "---" ]] || bad "$s: frontmatter must be exactly name + description"
done

# 7. Permission baselines parse and deny the dangerous things.
for f in framework/permissions/*/*.json; do
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null || bad "invalid JSON: $f"
done
grep -q '"Bash(git push \*)"' framework/permissions/claude/settings.json || bad "claude baseline does not deny git push"
grep -q '"disableBypassPermissionsMode": "disable"' framework/permissions/claude/settings.json || bad "claude baseline allows bypass mode"
grep -q '"Shell(git:push\*)"' framework/permissions/cursor/cli.json || bad "cursor baseline does not deny git push"
grep -q '"git push\*": "deny"' framework/permissions/opencode/opencode.json || bad "opencode baseline does not deny git push"
grep -q '^network_access = false' framework/permissions/codex/config.toml || bad "codex baseline allows network"
grep -q '^sandbox_mode = "workspace-write"' framework/permissions/codex/config.toml || bad "codex baseline sandbox is not workspace-write"
grep -q '"disableYoloMode": true' framework/permissions/gemini/settings.json || bad "gemini baseline allows yolo"

if [[ $fail -eq 0 ]]; then echo "OK    audit passed"; fi
exit $fail
