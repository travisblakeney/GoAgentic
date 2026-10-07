#!/usr/bin/env bash
# Install, verify, or remove the agents framework in one workspace.
#
#   scripts/install.sh <workspace> --harness <list> [--dry-run]   install or update
#   scripts/install.sh <workspace> --check                        verify (same as scripts/verify.sh)
#   scripts/install.sh <workspace> --uninstall                    remove managed files
#
#   <list> is comma-separated: claude,cursor,codex,gemini,opencode,pi
#   After the first install the list is remembered in the workspace; pass
#   --harness again only to change it.
#
# What it does, and does not do:
#   - Copies markdown from this checkout into the workspace. Nothing is linked back
#     to the checkout, so a later `git pull` here changes nothing until you re-run
#     this script and review the diff in the workspace.
#   - Writes only inside <workspace>. Never touches $HOME, never uses the network,
#     never needs sudo, never installs a binary, hook, service or scheduled job.
#   - Writes a harness permission file only if none exists. An existing one is left
#     alone and reported, so you can merge by hand.
#   - Refuses to write through symlinks.
#
# Works with macOS /bin/bash (3.2) and newer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FW_SRC="$ROOT/framework"
ALL_HARNESSES="claude cursor codex gemini opencode pi"

usage() { sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die() { echo "error: $*" >&2; exit 1; }

[[ -f "$FW_SRC/agents/CONVENTIONS.md" ]] || die "not a framework checkout: $ROOT"

MODE=install
DRY_RUN=false
WORKSPACE=""
HARNESS_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --dry-run) DRY_RUN=true ;;
    --check) MODE=check ;;
    --uninstall) MODE=uninstall ;;
    --harness) [[ $# -ge 2 ]] || die "--harness needs a value"; HARNESS_ARG="$2"; shift ;;
    --harness=*) HARNESS_ARG="${1#*=}" ;;
    -*) echo "unknown option: $1" >&2; usage 1 ;;
    *) [[ -z "$WORKSPACE" ]] || die "only one workspace may be given"; WORKSPACE="$1" ;;
  esac
  shift
done
[[ -n "$WORKSPACE" ]] || usage 1
[[ -d "$WORKSPACE" ]] || die "workspace is not a directory: $WORKSPACE"
[[ ! -L "$WORKSPACE" ]] || die "workspace path is a symlink; pass the real path: $WORKSPACE"
WORKSPACE="$(cd "$WORKSPACE" && pwd -P)"
case "$WORKSPACE" in "$ROOT"|"$ROOT"/*) die "workspace must not be inside the framework checkout" ;; esac

FW_DST_REL=".agents/agents-framework"
HARNESS_FILE="$WORKSPACE/$FW_DST_REL/harnesses"

# Harness list: argument, else the remembered list.
HARNESSES=""
if [[ -n "$HARNESS_ARG" ]]; then
  for h in $(echo "$HARNESS_ARG" | tr ',' ' '); do
    case " $ALL_HARNESSES " in *" $h "*) ;; *) die "unknown harness: $h (choose from: $ALL_HARNESSES)" ;; esac
    case " $HARNESSES " in *" $h "*) ;; *) HARNESSES="$HARNESSES $h" ;; esac
  done
elif [[ -f "$HARNESS_FILE" && ! -L "$HARNESS_FILE" ]]; then
  while IFS= read -r h; do
    case " $ALL_HARNESSES " in *" $h "*) HARNESSES="$HARNESSES $h" ;; esac
  done < "$HARNESS_FILE"
fi
HARNESSES="$(echo "$HARNESSES" | tr ' ' '\n' | sed '/^$/d' | sort | tr '\n' ' ' | sed 's/ $//')"
if [[ -z "$HARNESSES" && $MODE != uninstall ]]; then
  die "no harness given: pass --harness claude,cursor,codex,gemini,opencode,pi (any subset)"
fi
has() { case " $HARNESSES " in *" $1 "*) return 0 ;; esac; return 1; }

COMMANDS=""
for d in "$FW_SRC"/skills/agents-*/; do
  [[ -f "$d/SKILL.md" ]] || continue
  c="$(basename "$d")"; COMMANDS="$COMMANDS ${c#agents-}"
done
COMMANDS="${COMMANDS# }"

# Permission file per harness: "<workspace path>|<source under framework/permissions>"
perm_entry() {
  case "$1" in
    claude)   echo ".claude/settings.json|claude/settings.json" ;;
    cursor)   echo ".cursor/cli.json|cursor/cli.json" ;;
    codex)    echo ".codex/config.toml|codex/config.toml" ;;
    gemini)   echo ".gemini/settings.json|gemini/settings.json" ;;
    opencode) echo "opencode.json|opencode/opencode.json" ;;
    *)        echo "" ;;
  esac
}

# Managed paths (relative to the workspace) for the current harness list.
managed_dirs() {
  echo "$FW_DST_REL"
  for c in $COMMANDS; do echo ".agents/skills/agents-$c"; done
  if has claude; then for c in $COMMANDS; do echo ".claude/skills/agents-$c"; done; fi
}
managed_files() {
  if has gemini;   then for c in $COMMANDS; do echo ".gemini/commands/agents-$c.toml"; done; fi
  if has opencode; then for c in $COMMANDS; do echo ".opencode/commands/agents-$c.md"; done; fi
  if has pi;       then for c in $COMMANDS; do echo ".pi/prompts/agents-$c.md"; done; fi
}

# Refuse to operate through a symlink anywhere between the workspace and a path.
assert_no_symlink() {
  local rel="$1" acc="$WORKSPACE" part
  local IFS=/
  for part in $rel; do
    [[ -n "$part" ]] || continue
    acc="$acc/$part"
    if [[ -L "$acc" ]]; then die "refusing to use a symlink: ${acc#"$WORKSPACE"/}"; fi
  done
}

frontmatter_description() {  # the description: value of a SKILL.md, unquoted
  sed -n '2,/^---$/s/^description:[[:space:]]*//p' "$1" | head -1 | sed "s/^'//; s/'\$//; s/''/'/g"
}

wrapper_text() {  # $1 command, $2 how arguments arrive
  # shellcheck disable=SC2016  # the backticks are literal markdown
  printf 'Read `.agents/skills/agents-%s/SKILL.md` in this workspace and follow it exactly, as the `/agents-%s` command. %s\n' "$1" "$1" "$2"
}

# Build every managed file into a staging directory.
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/agents-framework.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
stage() {
  mkdir -p "$STAGE/$FW_DST_REL"
  cp -R "$FW_SRC/agents" "$FW_SRC/workspace" "$STAGE/$FW_DST_REL/"
  cp "$FW_SRC/VERSION" "$STAGE/$FW_DST_REL/VERSION"
  echo "$HARNESSES" | tr ' ' '\n' > "$STAGE/$FW_DST_REL/harnesses"
  cat > "$STAGE/$FW_DST_REL/README.md" <<'EOF'
# Installed agents framework — managed files

Everything under `.agents/agents-framework/` and `.agents/skills/agents-*/` (and
`.claude/skills/agents-*/`, plus the `agents-*` command wrappers) was copied here by
the framework's `scripts/install.sh`. Do not edit these files: change the framework
checkout, review it, and re-run the installer. `scripts/verify.sh <workspace>` reports
any difference between what is here and what the reviewed checkout would install.
EOF
  local c desc
  # shellcheck disable=SC2016  # $ARGUMENTS / $@ / {{args}} are literal placeholders for each CLI
  for c in $COMMANDS; do
    mkdir -p "$STAGE/.agents/skills/agents-$c"
    cp "$FW_SRC/skills/agents-$c/SKILL.md" "$STAGE/.agents/skills/agents-$c/SKILL.md"
    if has claude; then
      mkdir -p "$STAGE/.claude/skills/agents-$c"
      cp "$FW_SRC/skills/agents-$c/SKILL.md" "$STAGE/.claude/skills/agents-$c/SKILL.md"
    fi
    desc="$(frontmatter_description "$FW_SRC/skills/agents-$c/SKILL.md")"
    if has gemini; then
      mkdir -p "$STAGE/.gemini/commands"
      {
        printf 'description = "%s"\n' "$(printf '%s' "$desc" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        printf "prompt = '''\n"
        wrapper_text "$c" 'The arguments are: {{args}}'
        printf "'''\n"
      } > "$STAGE/.gemini/commands/agents-$c.toml"
    fi
    if has opencode; then
      mkdir -p "$STAGE/.opencode/commands"
      {
        printf -- "---\ndescription: '%s'\n---\n\n" "$(printf '%s' "$desc" | sed "s/'/''/g")"
        wrapper_text "$c" 'The arguments are: $ARGUMENTS'
      } > "$STAGE/.opencode/commands/agents-$c.md"
    fi
    if has pi; then
      mkdir -p "$STAGE/.pi/prompts"
      {
        printf -- "---\ndescription: '%s'\n---\n\n" "$(printf '%s' "$desc" | sed "s/'/''/g")"
        wrapper_text "$c" 'The arguments are: $@'
      } > "$STAGE/.pi/prompts/agents-$c.md"
    fi
  done
}

list_stage_files() { (cd "$STAGE" && find . -type f | sed 's|^\./||' | LC_ALL=C sort); }

# ---------------------------------------------------------------- check
do_check() {
  local fail=0 warn=0 f entry dst src extra
  [[ -d "$WORKSPACE/$FW_DST_REL" ]] || { echo "FAIL  framework not installed ($FW_DST_REL missing)"; return 1; }
  while IFS= read -r f; do
    if [[ -L "$WORKSPACE/$f" ]]; then echo "FAIL  symlink       $f"; fail=1
    elif [[ ! -f "$WORKSPACE/$f" ]]; then echo "FAIL  missing       $f"; fail=1
    elif ! cmp -s "$STAGE/$f" "$WORKSPACE/$f"; then echo "FAIL  modified      $f"; fail=1
    fi
  done < <(list_stage_files)
  # Files inside managed directories that the checkout would not install.
  while IFS= read -r d; do
    [[ -d "$WORKSPACE/$d" ]] || continue
    while IFS= read -r extra; do
      [[ -f "$STAGE/$extra" ]] || { echo "FAIL  unexpected    $extra"; fail=1; }
    done < <(cd "$WORKSPACE" && find "$d" \( -type f -o -type l \) | LC_ALL=C sort)
  done < <(managed_dirs)
  for h in $HARNESSES; do
    entry="$(perm_entry "$h")"; [[ -n "$entry" ]] || continue
    dst="${entry%%|*}"; src="$FW_SRC/permissions/${entry#*|}"
    if [[ -L "$WORKSPACE/$dst" ]]; then echo "FAIL  symlink       $dst"; fail=1
    elif [[ ! -f "$WORKSPACE/$dst" ]]; then echo "FAIL  missing       $dst  ($h permission baseline)"; fail=1
    elif ! cmp -s "$src" "$WORKSPACE/$dst"; then echo "WARN  differs       $dst  (compare with framework/permissions/${entry#*|})"; warn=1
    fi
  done
  if has pi; then echo "WARN  pi            Pi has no tool-approval gate; nothing enforces the deny list there"; warn=1; fi
  if [[ $fail -eq 0 ]]; then
    echo "OK    framework $(cat "$FW_SRC/VERSION") matches this checkout for: $HARNESSES"
    [[ $warn -eq 0 ]] || echo "      (warnings above need a human look)"
    return 0
  fi
  echo "Some managed files differ from this checkout. Review with 'git diff' / 'git status' in the workspace before re-installing."
  return 1
}

# ---------------------------------------------------------------- uninstall
do_uninstall() {
  local p
  # Remove what any harness could have installed, not only the remembered list.
  HARNESSES="$ALL_HARNESSES"
  while IFS= read -r p; do
    [[ -e "$WORKSPACE/$p" || -L "$WORKSPACE/$p" ]] || continue
    assert_no_symlink "$(dirname "$p")"
    if $DRY_RUN; then echo "would remove $p"; else chmod -R u+w "$WORKSPACE/$p" 2>/dev/null || true; rm -rf "${WORKSPACE:?}/$p"; echo "removed $p"; fi
  done < <(managed_dirs; managed_files)
  echo
  echo "Left in place: agents/ (your agents' files), instruction files, and harness permission files"
  echo "(.claude/settings.json, .cursor/cli.json, .codex/config.toml, .gemini/settings.json, opencode.json)."
}

# ---------------------------------------------------------------- install
do_install() {
  local p f entry dst src written=0
  while IFS= read -r p; do assert_no_symlink "$p"; done < <(managed_dirs; managed_files; for h in $HARNESSES; do e="$(perm_entry "$h")"; [[ -z "$e" ]] || echo "${e%%|*}"; done)

  if $DRY_RUN; then
    echo "Would write (managed, replaced on every install):"
    list_stage_files | sed 's/^/  /'
  else
    # Clear previous managed copies so files removed from the framework do not linger.
    while IFS= read -r p; do
      if [[ -e "$WORKSPACE/$p" ]]; then chmod -R u+w "$WORKSPACE/$p" 2>/dev/null || true; rm -rf "${WORKSPACE:?}/$p"; fi
    done < <(managed_dirs; managed_files)
    while IFS= read -r f; do
      mkdir -p "$WORKSPACE/$(dirname "$f")"
      cp "$STAGE/$f" "$WORKSPACE/$f"
      chmod a-w "$WORKSPACE/$f"   # defence in depth: agents' file tools fail on read-only files
      written=$((written + 1))
    done < <(list_stage_files)
    echo "Wrote $written managed files (read-only) for: $HARNESSES"
  fi

  echo
  echo "Harness permission baselines:"
  for h in $HARNESSES; do
    entry="$(perm_entry "$h")"
    if [[ -z "$entry" ]]; then
      [[ $h == pi ]] && echo "  pi        NO ENFORCEMENT — Pi has no tool-approval gate. Use it only where that is acceptable."
      continue
    fi
    dst="${entry%%|*}"; src="$FW_SRC/permissions/${entry#*|}"
    if [[ ! -e "$WORKSPACE/$dst" ]]; then
      if $DRY_RUN; then echo "  $h  would write $dst"
      else mkdir -p "$WORKSPACE/$(dirname "$dst")"; cp "$src" "$WORKSPACE/$dst"; echo "  $h  wrote $dst"; fi
    elif cmp -s "$src" "$WORKSPACE/$dst"; then
      echo "  $h  $dst already matches the baseline"
    else
      echo "  $h  $dst EXISTS AND DIFFERS — left untouched. Merge the rules from:"
      echo "            $src"
    fi
  done

  echo
  echo "Next:"
  echo "  1. Review and commit the change in the workspace:  git -C \"$WORKSPACE\" status"
  has codex  && echo "  -  Codex: trust this project when asked, or .codex/config.toml is ignored."
  has gemini && echo "  -  Gemini: project policies are ignored by Gemini today. Once, at user level:  cp \"$FW_SRC/permissions/gemini/agents-framework.policy.toml\" ~/.gemini/policies/"
  echo "  2. Open the workspace in your CLI and run /agents-init (Codex: \$agents-init)."
  echo "  3. Later, verify nothing changed the managed files:  $ROOT/scripts/verify.sh \"$WORKSPACE\""
}

case $MODE in
  check)     stage; do_check ;;
  uninstall) do_uninstall ;;
  install)   stage; do_install ;;
esac
