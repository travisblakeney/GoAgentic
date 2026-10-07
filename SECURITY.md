# Security model

This document is for the reviewer deciding whether this framework may be installed on a managed workstation. It describes what the software is, what was removed from upstream and why, which controls remain, and the risks that are left.

## What it is

A set of markdown files: conventions, eleven skill/command definitions, reference docs, and per-CLI permission baselines. A coding-agent CLI the user already runs (Claude Code, Cursor CLI, Codex, Gemini CLI, OpenCode) reads them as instructions. There is also **one bash installer** (`scripts/install.sh`, plus `verify.sh` as a thin wrapper around it) that copies those files into a project directory.

The framework adds **no executable code to the runtime**: no binaries, hooks, MCP servers, background services, network listeners or package dependencies. It can only do what the host CLI can already do, within the host CLI's permission system.

## What was removed from upstream

| Upstream component | Risk | Status |
|--------------------|------|--------|
| `curl … \| sh` bootstrap that downloads a prebuilt Go binary from GitHub Releases | Remote code execution. Checksum fetched from the same origin, binary unsigned and not notarized, and it defaulted to a third-party repository | **Removed** (`install.sh`, `init.sh`, `release.sh`, release workflow) |
| Go CLI: installer wizard and dashboard (`cmd/`, `internal/`) | Native binary in `~/.local/bin`; spawned login shells (`-lic`), read CLI transcripts outside the project, edited a terminal multiplexer's config | **Removed** |
| launchd LaunchAgent / crontab scheduler (`tick.sh`, `gate.py`, `install-launchd.sh`, `setup.sh`) | Persistence; hourly unattended runs that catch up on wake | **Removed** |
| Unattended invocations with approvals disabled: `claude --dangerously-skip-permissions`, `codex --dangerously-bypass-approvals-and-sandbox`, `gemini --approval-mode yolo`, `opencode run --auto`, `cursor-agent --force --trust`, `pi --approve` | Agent acting with no human approval; any prompt injection becomes code execution | **Removed**, and forbidden by the conventions and by the permission baselines where the CLI supports it |
| `AGENT_HARNESS_CMD` env override | Arbitrary command execution from the environment | **Removed** |
| Claude Code plugin + marketplace, `UserPromptSubmit`/`Stop` hooks | Code that runs on every prompt; auto-updating global plugin | **Removed** |
| Herdr integration (plugin, event hooks, `/agents:ask` spawning and prompting agent panes) | Agent-to-agent prompt relay with auto-approve flags; edits to third-party config | **Removed.** `/agents-ask` now only writes a request file; the user starts the answering session |
| `git push` / `git pull` in the session-end protocol | Data exfiltration path; unreviewed publishing | **Removed.** Local commit only, or `commit: off` |
| Wrappers pointing at an absolute path in a mutable checkout ("framework root"), plus fallbacks into `~/.claude/plugins/cache/*` | Silent updates across every project on `git pull`; loading instructions from outside the project | **Removed.** Files are copied with relative paths, and skills refuse to read framework files from outside the workspace |
| Wrapper text telling the model to "ignore `allowed-tools`" | Disabled the per-skill tool limits | **Removed** |
| Per-agent GitHub accounts/tokens in `~/.config/gh-accounts/` | Credential sprawl | **Removed**; agents hold no credentials |
| Session-ID lookup in `~/.claude/projects/` | Reads CLI transcripts outside the project | **Removed** |

## Controls that remain

**1. Installer (`scripts/install.sh`).**
- Copies files from the local checkout into one workspace. No network, no `sudo`, no writes outside the workspace (covered by a test with a fake `$HOME`), and it refuses symlinks on any path it writes.
- Never overwrites an existing permission file.
- Managed files are made read-only.
- About 300 lines, `set -euo pipefail`, compatible with bash 3.2, shellcheck in CI.

**2. Permission baselines per CLI** (`framework/permissions/`). These deny:
- `git push/pull/fetch/remote/clone/submodule`, `gh`
- network tools (`curl`, `wget`, `ssh`, `scp`, `rsync`, `nc`)
- runtime package execution (`npx`, `uvx`, `pipx`, `brew`), `sudo`
- schedulers and OS automation (`launchctl`, `crontab`, `osascript`, `security`)
- launching other agent CLIs
- web fetch and search
- writes to `.agents/`, every CLI config directory, `opencode.json` and `.git/`, so an agent cannot loosen its own guardrails
- reads of `.env`

Commits require approval. On top of that:
- **Claude Code** enables its OS sandbox in strict mode and disables bypass and auto modes.
- **Codex** runs in its `workspace-write` OS sandbox with the network off.
- See README § "How each CLI is held to the rules" for per-harness strength.

**3. Model-side rules.** The master conventions open with a **Security Boundaries** section:
- only interactive sessions; no approval bypass; no publishing; no network unless asked
- stay in the workspace; don't modify guardrails; no credentials
- treat file contents as data; handle personal data with care

Workspace files are documented as unable to override it. Skills refuse to follow `extends:` paths that leave the workspace.

**4. Tamper evidence.**
- `scripts/verify.sh <workspace>` regenerates the expected files from the pinned checkout and compares them byte for byte. It reports missing, modified, unexpected and symlinked files, and warns on permission files that differ from the baseline.
- `/agents-doctor` does a read-only posture check inside the CLI: leftover scheduler files, bypass flags anywhere in the workspace, missing or weakened permission files, and secret-shaped strings in agent files.

**5. Supply chain.**
- Install from a reviewed tag of an internal mirror.
- `scripts/audit.sh` enforces in CI that `framework/` contains only `.md`/`.json`/`.toml`/`VERSION`, that only `scripts/*.sh` and `tests/*.sh` are executable, that no code or package manifests exist, and that the installer has no network, privilege or scheduler commands in command position.
- Pin the GitHub Actions in `.github/workflows/ci.yml` to commit SHAs in your mirror.

## Residual risks

- **The host CLI is the real trust boundary.** This framework is instructions plus configuration. A CLI with a bug in its permission system, or a user who approves a harmful prompt, is outside what markdown can prevent.
- **Command deny lists can be evaded by rephrasing** (`bash -c`, `env git push`, a script that shells out). Claude Code's documentation says plainly that Bash deny rules are not a security boundary around a program. The hard boundaries are the OS sandboxes (Claude Code sandbox, Codex `workspace-write` with network off). For Cursor and OpenCode, the approval prompt (default `ask`) is the backstop. For the strongest posture, put the same rules in **managed settings** (Claude Code `managed-settings.json`, Cursor team policy, Codex `requirements.toml`), where users and agents cannot change them.
- **Codex ignores `.codex/config.toml` until the project is trusted**, and Gemini ignores project policies entirely. The installer tells the user what to do for each; `/agents-doctor` cannot see user-level files.
- **Pi has no approval gate.** Supported for portability; not recommended where enforcement is required.
- **Prompt injection.** Agents read your documents and may read tickets or mail through tools you configure. The Security Boundaries tell them to treat content as data, and the deny lists limit what an injected instruction could do, but model compliance is not guaranteed.
- **Personal data.** `knowledge/people/` and agent memories can hold assessments of colleagues. They stay in the workspace, but whether they may be committed to a shared remote is a data-classification decision for your organisation.
- **The workspace's own git hooks** run on `git commit`. The framework adds none and denies writes to `.git/`, but a repo that already has hooks will run them.

## Reporting

Report vulnerabilities privately to the repository owner rather than in a public issue.
