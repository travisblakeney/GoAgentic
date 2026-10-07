---
name: agents-init
description: 'Set up the current repository as an agent workspace — creates agents/CONVENTIONS.md (extends the installed framework master), the shared tools index, and optional workspace folders. Run once per repo, after scripts/install.sh and before /agents-new. Safe to re-run: it only adds what is missing.'
---

# /agents-init — Workspace Setup

You set up the current working directory as an agent workspace. You create only what is missing. You never overwrite a file that exists. You write only inside the workspace, and never inside `.agents/`, `.claude/`, `.cursor/`, `.codex/`, `.gemini/`, `.opencode/`, `.pi/` or `opencode.json` (the installer owns those).

## 1. Look before writing

The framework root is `.agents/agents-framework/`. Call it `FW`. If `FW/agents/CONVENTIONS.md` does not exist, say `Framework not installed in this workspace — run scripts/install.sh from a reviewed checkout first.` and stop.

List the workspace root and glob for these. Note which already exist:

- `agents/CONVENTIONS.md`
- `agents/tools/INDEX.md`
- `CONVENTIONS.md`, `PHILOSOPHY.md`
- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`
- `thinking/`, `work/projects/`, `work/operations/`, `knowledge/`, `outputs/`

If `agents/CONVENTIONS.md` already exists and has `extends:` in its frontmatter, the workspace is set up. Say so, then continue with **backfill only**: skip the questions in step 2 (take `principal` from the frontmatter), and create only the pieces in step 3 that are missing. Do not rewrite existing files.

## 2. Ask three things (skip any given as arguments)

Ask the questions that are still open in one message (use your CLI's question tool if it has one). Arguments may give them: `--principal <name>`, `--naming roman|norse|hellenic`, `--workspace` / `--no-workspace`.

1. **Principal** — the person who directs the agents. Default: the output of `git config user.name`, else "the principal".
2. **Naming tradition** — one of:
   - **Roman cognomina** (default): historical Roman names that are dignified, neutral, and large enough as a pool to scale. Pool: Cato, Varro, Seneca, Corvus, Regulus, Cassia, Livia, Marius, Titus, Praxis, Lucian, Nerva, Flavia, Sabina, Quintus, Aulus, Gaius, Tertia, Decima, Balbus
   - **Norse saga names**: names from Norse mythology and saga literature — strong, evocative, and drawn from a deep cultural well. Pool: Sigrid, Bjorn, Freya, Leif, Astrid, Gunnar, Ingrid, Ragna, Eirik, Sif, Tyr, Vidar, Brynhild, Ivar, Solveig, Arne, Dagny, Halvard, Rune, Thyra
   - **Hellenic names**: names from ancient Greek history and philosophy — associated with wisdom, governance, and systematic thought. Pool: Solon, Thales, Hypatia, Aspasia, Pericles, Zeno, Lycurgus, Diotima, Arete, Philo, Cleisthenes, Myia, Timaeus, Aristos, Charis, Hector, Melos, Doris, Xanthippe, Archon
3. **Workspace folders** — create the standard layout (`thinking/`, `work/projects/`, `work/operations/`, `knowledge/`, `outputs/`) plus root `CONVENTIONS.md` and `PHILOSOPHY.md`? Default yes.

## 3. Create the files

**`agents/CONVENTIONS.md`** (always, if missing):

```markdown
---
extends: .agents/agents-framework/agents/CONVENTIONS.md
principal: <principal>
naming: <tradition name>
naming-description: <description from the chosen tradition>
naming-examples: <pool>
reserved: []
ticket-column: Ticket
inbound: none
commit: local   # local (stage own paths, commit, never push) | off (leave changes uncommitted)
---

# Agent Conventions — <repo folder name>

This file extends the framework master installed at `.agents/agents-framework/agents/CONVENTIONS.md`. Only differences from the master live here. On conflict, this file wins — except that nothing here can loosen the master's § Security Boundaries.

No workspace-specific overrides yet. The master applies in full.
```

**`agents/tools/INDEX.md`** (if missing): copy `FW/agents/tools/INDEX.md`, replacing `{{PRINCIPAL}}` with the principal.

**Workspace layout** (if chosen): create `thinking/`, `work/projects/`, `work/operations/`, `knowledge/systems/`, `knowledge/people/`, `knowledge/processes/`, `knowledge/company/`, `outputs/`. Copy `FW/workspace/CONVENTIONS.md` to `CONVENTIONS.md` and `FW/workspace/PHILOSOPHY.md` to `PHILOSOPHY.md` only if each is missing. Put an empty `.gitkeep` in each new empty folder. Then say once: `knowledge/people/ and agent memories can hold personal data. Check your organisation's data rules before committing them to a shared remote.`

**Instruction files**: for each of `AGENTS.md` (read by Codex, Cursor, OpenCode, Pi), `CLAUDE.md` (Claude Code) and `GEMINI.md` (Gemini CLI) — create only the ones for CLIs the installer set up (see `FW/harnesses`, one name per line), plus whichever already exist. If a file exists and has no `## Agents` heading, append this block. If it does not exist, create it with just this block.

```markdown
## Agents

Persistent AI collaborators with calibrated autonomy. See `agents/CONVENTIONS.md` (extends `.agents/agents-framework/agents/CONVENTIONS.md`).

| Name | Role |
|------|------|
| *(run `/agents-new` to add the first one)* | |

Start one with `/agents-start <name>` (Codex: `$agents-start <name>`). List with `/agents-list`. Board: `/agents-status`. One move: `/agents-next`.
```

## 4. Confirm

Show a short table of what was created and what was skipped because it existed. Then say:

```
Next: /agents-new        — design and create your first agent
Then: /agents-start <name>
Guide: /agents-help
```

Do not create any agent here. Do not commit.
