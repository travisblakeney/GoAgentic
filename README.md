# GoAgentic (hardened, portable)

A convention-based system for building persistent AI collaboration partners: agents that challenge your thinking, drive the agenda, and hold you accountable. This edition is **markdown only** and works with any coding-agent CLI that reads skills: Claude Code, Cursor CLI, Codex, Gemini CLI, OpenCode, and Pi.

It is a hardened fork of [normannoble/GoAgentic](https://github.com/normannoble/GoAgentic), built to pass a corporate security review on a managed Mac. In short:

- **Nothing to execute.** No binaries, no `curl | sh`, no hooks, no plugins fetched from a marketplace. The installer is one short, readable, offline bash script that copies markdown into a workspace.
- **Nothing runs in the background.** The launchd/cron scheduler and unattended `--dangerously-skip-permissions` / `--yolo` / `--force` runs are gone. Every session is one you started.
- **No publishing.** Agents commit locally; they never push, pull or fetch.
- **Guardrails enforced by the CLI itself, not just the prompt.** Each harness gets a permission file that denies push, network tools, schedulers, approval bypass, and edits to the framework and to the permission files themselves.
- **Tamper-evident.** `scripts/verify.sh` compares every installed file byte for byte against the reviewed checkout.

[SECURITY.md](SECURITY.md) has the threat model, everything that was removed, and the remaining risks. That is the document to hand to a security team.

## Why this approach

Most AI agent setups build obedient assistants. You tell them what to do, they do it, they report back. That works for repeatable tasks with clear playbooks. It fails for the work that actually needs a collaborator — strategy, prioritisation, synthesis, judgment under ambiguity.

This framework takes the opposite position. Agents are **drivers, not passengers.** At session start, the agent reviews its action tracker and declares what it thinks the priorities are. You agree, redirect, or override — but the agent sets the agenda. When conversation drifts from declared priorities, the agent notices and names it. The autonomy model isn't about delegation; it's about **calibrating collaboration**. See [PHILOSOPHY.md](framework/workspace/PHILOSOPHY.md).

## Quick start

```bash
# 1. Get a copy of the framework and pin it to a reviewed tag
git clone https://github.com/travisblakeney/GoAgentic.git ~/tools/goagentic
cd ~/tools/goagentic && git checkout <reviewed-tag>
scripts/audit.sh && tests/run.sh          # optional: re-run the checks yourself

# 2. Install into a workspace, for the CLIs you use
scripts/install.sh ~/work/my-agents --harness cursor,claude

# 3. Review and commit what it wrote
git -C ~/work/my-agents status
```

Then open the workspace in your CLI:

```
/agents-init            set up agents/CONVENTIONS.md (once)
/agents-new             design your first agent
/agents-start <name>    start a session with it
/agents-wrap            end the session: tracker, memory, local commit
```

In Codex, type `$agents-<cmd>` instead of `/agents-<cmd>`.

## What the installer writes

`scripts/install.sh <workspace> --harness <list>`. `<list>` is any of `claude,cursor,codex,gemini,opencode,pi`.

| Path in the workspace | What it is | Managed? |
|-----------------------|------------|----------|
| `.agents/agents-framework/` | Master conventions, reference docs, templates, `VERSION`, `harnesses` | Yes: replaced on each install, read-only, verified |
| `.agents/skills/agents-*/SKILL.md` | The 11 commands (read by Cursor, Codex, OpenCode, Gemini, Pi) | Yes |
| `.claude/skills/agents-*/SKILL.md` | The same skills for Claude Code | Yes, if `claude` |
| `.gemini/commands/`, `.opencode/commands/`, `.pi/prompts/` `agents-*` | One-line slash-command wrappers that point at the skill | Yes, for those harnesses |
| `.claude/settings.json`, `.cursor/cli.json`, `.codex/config.toml`, `.gemini/settings.json`, `opencode.json` | Permission baselines | Written only if absent. An existing file is never overwritten; you're told to merge it |

Everything is copied, never linked, and uses only relative paths. Changing the checkout changes nothing until you re-run the installer, and that shows up as a diff in the workspace for review. The installer never writes outside the workspace, never touches `$HOME`, and never uses the network. It refuses to write through symlinks. `--dry-run` shows what it would do; `--uninstall` removes the managed files and leaves your agents and permission files in place.

## How each CLI is held to the rules

| Harness | Enforcement | Strength |
|---------|-------------|----------|
| **Claude Code** | `.claude/settings.json`: deny rules, `disableBypassPermissionsMode`, `disableAutoMode`, and the OS sandbox (`sandbox.enabled`, `failIfUnavailable`, `allowUnsandboxedCommands: false`). The sandbox starts with no allowed network domains | Strong: the shell sandbox is enforced by the OS |
| **Codex** | `.codex/config.toml`: `sandbox_mode = "workspace-write"`, `network_access = false`, `approval_policy = "on-request"`, `web_search = "disabled"`. **Loaded only after you trust the project** | Strong: the sandbox is enforced by the OS |
| **Cursor CLI** | `.cursor/cli.json`: `Shell(...)`, `Write(...)`, `WebFetch(...)` deny rules (deny beats allow). Never run `cursor-agent` with `--force` or `--trust` | Medium: rules match commands |
| **OpenCode** | `opencode.json`: `permission` rules, default `ask`, web tools `deny` | Medium: rules match commands |
| **Gemini CLI** | `.gemini/settings.json` (`disableYoloMode`, web tools excluded), plus `framework/permissions/gemini/agents-framework.policy.toml`, which **you copy once to `~/.gemini/policies/`**, because Gemini ignores project-level policies today | Medium, once the user policy is installed |
| **Pi** | None: Pi has no tool-approval gate | Only the model-side rules apply. Avoid where enforcement is required |

On every harness the master conventions also carry a binding **Security Boundaries** section that the model follows and no workspace file can loosen. Command-matching deny lists are best effort (a determined model can rephrase a command); the OS sandboxes are the hard boundary. See [SECURITY.md](SECURITY.md#residual-risks).

## Using it across projects

Pick one. They can be combined.

1. **One agents workspace (recommended).** Keep all agents, their memory, and your people notes in one dedicated repo (local only, or on an approved internal remote). Agents work on code repos that you list in their `tools.md`, each in its own git worktree. One install covers everything, and agent state never lands in company code repos. Cross-project use is built in, because the workspace *is* the cross-project layer.
2. **Copy into each repo from one pinned checkout.** Run `scripts/install.sh <repo> --harness …` for each project that should have agents. Upgrades are a `git checkout <new-tag>` in the checkout plus re-running the installer per repo. Every change arrives as a reviewable diff, and `scripts/verify.sh <repo>` proves each copy is untouched.
3. **Your company's internal distribution.** If your org has a Cursor team marketplace, an internal Claude Code plugin marketplace, or similar, publish `framework/` from an internal mirror of this repo. Security reviews one repo; admins control rollout. The permission baselines still go into each workspace (or into managed settings, which is stronger).

There is deliberately no "install globally into `~/.something`" mode: user-level skills apply to every repo you open, including ones where you don't want agents, and they are harder to audit.

## Commands

| Command | What it does |
|---------|--------------|
| `/agents-help` | The guide |
| `/agents-init` | Set up the current repo as a workspace (run once; safe to re-run) |
| `/agents-new` | Design and create an agent, interactively |
| `/agents-start <name> [topic]` | Run an agent (`<name> close` to end, `<name> peer <file>` to answer a peer request) |
| `/agents-wrap` | End the session: tracker, memory, local commit |
| `/agents-close` | Same as wrap, then asks you to clear the conversation |
| `/agents-list` | List agents (`<scope>` to filter, `all` to include retired) |
| `/agents-status` | Org status board |
| `/agents-next` | The single next best action across the org |
| `/agents-doctor` | Read-only health and security-posture review |
| `/agents-ask <name> "<request>"` | Write a request for another agent. You start the target to answer it |

## How it works

### Agents are files

Each agent is a directory of markdown files under `agents/`:

```
agents/<name>/
├── role.md          What the agent does — purpose, outcomes, boundaries
├── soul.md          How it communicates — voice, temperament, values
├── name.md          The historical figure behind the name and why it fits
├── autonomy.md      Authority levels — what it owns vs. what it flags
├── tools.md         Agent-specific tool notes (never credentials)
├── actions.md       Standing to-do list, updated every session
├── actions-archive.md  Completed actions older than 30 days
├── context.md       Startup file paths and project references
├── MEMORY.md        Index of standing knowledge and session logs
├── memory/
│   ├── standing/    Durable rules, decisions, baselines (all loaded on startup)
│   └── sessions/    Per-session logs (most recent 2 loaded on startup)
├── peer/            Requests from other agents, and replies
└── playbooks/       Repeatable procedures with defined execution modes
```

No database, no API, no runtime. Just markdown in your git repo.

### The autonomy model

Based on *Turn the Ship Around* by L. David Marquet. Agents operate on a five-level authority ladder:

| Level | Agent says | Meaning |
|-------|-----------|---------|
| **L5 — Own** | *(in summary)* | Acts independently, reports at close |
| **L4 — Act & Inform** | "I've done X." | Acts, then flags |
| **L3 — Intend** | "I intend to..." | States intent, proceeds unless redirected |
| **L2 — Recommend** | "I recommend..." | Presents analysis, waits for approval |
| **L1 — Flag** | "I see a problem..." | Surfaces for you to decide |

New agents start conservative (mostly L2). Authority moves up the ladder as trust is demonstrated. In this edition the ladder sits **inside** the Security Boundaries: no promotion lets an agent push, reach the network unasked, schedule work, or edit its own guardrails.

### Sessions

| Type | Who starts it | May write |
|------|---------------|-----------|
| **Session** | You, with `/agents-start <name>` | Memory, tracker, local commit |
| **Peer** | You, with `/agents-start <name> peer <file>` after another agent ran `/agents-ask` | The reply section of one file in `peer/` |

The upstream "tick" session type (unattended scheduled runs) is removed. Work on a cadence becomes a playbook with a trigger, and the agent raises it the next time you start it.

### Memory, playbooks, tooling

Unchanged from upstream apart from the security rules: standing and session memory with consolidation limits; playbooks with four execution modes (Autopilot, Maker-Checker, Exception-Based, Paired); three-level tool configuration (`agents/tools/INDEX.md` → `agents/tools/<tool>.md` → `<agent>/tools.md`). Tools run under your own logged-in CLI sessions, approved per call by the harness. Agents never get their own accounts or tokens.

## Developing the framework

```bash
scripts/audit.sh     # static invariants: data-only framework, no network in the installer, baselines deny push
tests/run.sh         # end-to-end installer tests in throwaway workspaces
```

CI runs both on Linux and on macOS's `/bin/bash` 3.2, plus `shellcheck`. Bump `framework/VERSION` and tag a release for every change to `framework/`.

## Background

The session mechanics — priority declaration, compass checks, drift management — exist because AI agents have a strong recency bias. Without explicit structure, conversation momentum displaces strategic priorities. The memory system is designed around the constraint that CLI sessions don't share context: standing memories give agents institutional knowledge, session logs give them continuity, and consolidation rules prevent context bloat.

License: see [LICENSE](LICENSE).
