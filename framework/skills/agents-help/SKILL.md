---
name: agents-help
description: 'How the agents framework works — the commands, the flow from setup to daily use, what an agent is made of, and fixes for common problems. Use /agents-help, or /agents-help <command> for one command.'
---

# /agents-help — Guide

If the arguments name a command, read `.agents/skills/agents-<command>/SKILL.md`. Print its `description`, then explain what it does in five lines or fewer, in plain words. Stop.

Otherwise your whole reply is the guide below, **as is**. Start with its first heading. No sentence before it, nothing after it. Do not read any file.

---

# Agents — quick guide

An **agent** is a named, persistent collaborator that lives in this repo as markdown files. It keeps its own memory, its own action tracker, and a level of autonomy you set. You start it by name and it becomes that agent for the session. In Codex, type `$agents-<cmd>` instead of `/agents-<cmd>`.

## Commands

| Command | What it does |
|---------|--------------|
| `/agents-init` | Set up this repo as a workspace. Run once. Re-run to backfill missing pieces. |
| `/agents-new` | Design and create an agent. Asks you questions. |
| `/agents-start <name>` | Start an agent. It reads its files and tells you its priorities. |
| `/agents-start <name> <topic>` | Start an agent and work on one thing. |
| `/agents-start <name> close` | End the session. The agent saves memory and updates its tracker. |
| `/agents-wrap` | End the active session and save state (memory, tracker, local commit). Run from inside the session; no name needed. |
| `/agents-close` | Same as `/agents-wrap`, then asks you to clear the conversation. |
| `/agents-list` | List agents. Add `<scope>` to filter, `all` to include retired ones. |
| `/agents-status` | Live board: each agent's role, current focus, and freshness. |
| `/agents-next` | The single next best action across all agents, and why. |
| `/agents-doctor` | Health review. Finds bloat, stale trackers, missing files, risky settings. Recommends fixes. Changes nothing. |
| `/agents-ask <name> "<request>"` | Write a request for another agent. You then start that agent with the command it prints to get the reply. |
| `/agents-help <command>` | Details for one command. |

## The flow

1. **First time in a repo:** someone runs `scripts/install.sh` from a reviewed copy of the framework, then `/agents-init`, then `/agents-new`.
2. **Each working session:** `/agents-start <name>` (or with a topic). Do the work. `/agents-wrap` when done (or `/agents-close` to also start fresh).
3. **When you do not know where to go:** `/agents-status` for the whole board, `/agents-next` for the one move.
4. **Once a week or so:** `/agents-doctor`. Run the commands it gives you. Also run `scripts/verify.sh <workspace>` from the framework checkout to confirm nothing changed the installed framework or permission files.
5. **When one agent needs another:** `/agents-ask <name> "<request>"` from inside the asking agent's session, then start the target yourself with the `peer` command it prints. Same workspace only. The reply lands in `agents/<Name>/peer/`.

Nothing runs while you are away. There is no scheduler, no background job and no auto-push: every session is one you started, and every commit stays local until you push it.

Always run these from the workspace root (the folder that holds `agents/`).

## What an agent is made of

```
agents/<Name>/
  role.md        what it does and its goals
  soul.md        how it thinks and talks
  autonomy.md    what it may do alone (L1 ask … L5 act and report)
  tools.md       the tools it may use
  actions.md     its action tracker (P1 / P2 / P3, Completed)
  context.md     scope, title, extra files to read at startup
  MEMORY.md      index of its memory
  memory/        standing/ (durable) and sessions/ (one per session)
  reference/     optional: situational rules and detail, read on demand
  peer/          requests from other agents, and their replies
  playbooks/     repeatable procedures with triggers
```

`agents/CONVENTIONS.md` holds the rules for this workspace. It is short and extends the master at `.agents/agents-framework/agents/CONVENTIONS.md`. The workspace file wins on conflict, except that it cannot loosen the master's Security Boundaries.

## Common problems

- **"Unknown command" after install or update.** Restart your CLI; most load skills at start. Codex and Gemini may also ask you to trust the folder first.
- **"Framework not installed in this workspace."** Run `scripts/install.sh <workspace> --harness <list>` from your reviewed framework checkout.
- **A permission prompt for `git commit`.** Expected: commits are allowed but ask first. Push, pull and fetch are denied; run them yourself.
- **An agent starts slowly or uses many tokens.** Run `/agents-doctor`. Usually the tracker or standing memory has grown. The doctor names the file.
- **An agent is gone from `/agents-list`.** It is retired. `/agents-list all` shows it. `/agents-start <name>` still works.
- **`scripts/verify.sh` reports a modified file.** Something edited the framework, a skill, or a permission file. Look at the diff (`git diff` in the workspace) before reinstalling with `scripts/install.sh`.
- **Update the framework:** in the framework checkout, check out the new reviewed tag, then re-run `scripts/install.sh <workspace>`. Commit the resulting diff in the workspace so the change is visible in review.
