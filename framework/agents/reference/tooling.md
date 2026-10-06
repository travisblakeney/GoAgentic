# Tooling: Autonomy Integration, Admin Checklist, Adding a Tool

Reference for `agents/CONVENTIONS.md` (the master). Loaded on demand, not at startup.

### Autonomy Integration

Each tool file (`agents/tools/<tool>.md`) defines default autonomy levels for its actions. Agents override these in their `autonomy.md` as trust develops through the standard promotion/demotion process.

Suggested defaults for new agents:

| Action | Default Level |
|--------|--------------|
| Read communications / calendar / shared files | L5 — Own |
| Read issues / projects | L5 — Own |
| Update issue status | L4 — Act & Inform |
| Send internal communication (routine) | L3 — Intend |
| Send internal communication (sensitive) | L2 — Recommend |
| Create issues, add comments | L3 — Intend |
| Create / modify calendar events | L3 — Intend |
| Read PRs, checks, CI status | L3 — Intend (each call still passes the harness approval prompt) |
| Create local branches and commits | L4 — Act & Inform |
| Push code, open or merge PRs | Blocked — {{PRINCIPAL}} does it |
| Review PRs (draft comments for {{PRINCIPAL}} to post) | L3 — Intend |
| Review PRs (approve/request changes) | Blocked — {{PRINCIPAL}} does it |
| Browse public websites (research, documentation) | L2 — Recommend (web tools are denied by default; {{PRINCIPAL}} enables per session) |
| Browse authenticated internal tools | Blocked — requires explicit promotion and a harness allow rule |
| Read-only data queries (non-production) | L3 — Intend |
| Read-only data queries (production) | L2 — Recommend |
| Write data queries | Blocked — requires explicit promotion |
| Send external communication | Blocked — requires explicit promotion |

"Sensitive" is left to agent judgment — examples include escalations, legal matters, anything involving external stakeholders, or communications that could set expectations on behalf of the organisation.

### Credentials

Agents hold no credentials of their own.

- **No agent accounts or tokens.** Do not create service accounts, personal access tokens, API keys or per-agent config directories for agents. A tool that needs authentication runs under {{PRINCIPAL}}'s own logged-in CLI or MCP session, and the harness asks {{PRINCIPAL}} before each call that is not on its allow list.
- **Nothing secret in the workspace.** Never write a token, password, key, cookie, or the path of a file that holds one into any agent file, memory, peer request, or tool reference. `/agents-doctor` greps for common secret shapes.
- **MCP servers** are configured by {{PRINCIPAL}} in the harness, pinned to a reviewed version, never started by an agent with `npx`/`uvx` on the fly. An agent's `tools.md` names the server; it does not configure it.
- **Network use** (web fetch, search, API calls) is denied by default in the shipped permission files. {{PRINCIPAL}} grants it per session, or by adding a narrow allow rule (one domain, one command) in the harness's own config, reviewed like any code change.

### Post-Creation Admin Checklist

After `/agents-new` completes, external setup may be wanted. Skip any step for a tool the workspace does not use; add workspace-specific steps in the workspace `agents/CONVENTIONS.md`.

1. **Issue tracker label** — e.g. a label `<name>` under an Agent group, so items the agent drafts are easy to find. {{PRINCIPAL}} applies it.
2. **Allow rules** — if the agent needs a read-only command often (e.g. `gh pr view`), {{PRINCIPAL}} adds one narrow allow rule to the harness permission file and commits it. Never a wildcard.
3. **Record the setup** in the agent's `tools.md` (display name, which allow rules exist) — no credentials.

### Adding a New Tool

When introducing a new tool to the agent framework:

1. **Tool file** — Create `agents/tools/<tool>.md` with setup, commands, scope constraints, and autonomy defaults
2. **Tools index** — Add a row to the table in `agents/tools/INDEX.md`
3. **Agent tools.md** — Add the tool section to each agent that needs access, with agent-specific config (identity, commands)
4. **Agent autonomy.md** — Add the tooling actions at the appropriate levels, with a changelog entry
5. **Create-agent skill** — If the tool applies to all agents, update the `tools.md` template reference in the skill
6. **This checklist** — If the tool requires manual admin setup, add a step to the Post-Creation Admin Checklist above
