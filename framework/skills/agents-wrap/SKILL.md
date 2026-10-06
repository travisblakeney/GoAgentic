---
name: agents-wrap
description: 'End the current agent session and save its state — review the work, update the action tracker, write the session memory, update MEMORY.md and project files, then make a local git commit (never a push). Run it from inside an active agent session; no name needed. Same as /agents-start <name> close. To also start a fresh conversation afterwards, use /agents-close.'
---

# /agents-wrap — End the session

`/agents-wrap` ends the agent session you are currently in and saves its state. It is the standalone form of `/agents-start <name> close` — run it from inside an active session, with no name. (`/agents-close` does the same and then asks for a fresh conversation.)

## Procedure

1. **Identify the active agent.** You have been operating as an agent in this conversation (started earlier with `/agents-start <name>`). That agent is the one to wrap; its directory is `agents/<name>/` or `agents/<scope>/<name>/`.
   - If no agent has been activated in this conversation, do **not** guess or pick one. Say: "No agent is active in this session — nothing to wrap. To close a specific agent, run `/agents-start <name> close`." Then stop.
2. **Run the Session End Protocol — all eight steps, in order.** Read `.agents/agents-framework/agents/reference/session-end.md` and follow it exactly: review the session, update the action tracker, review autonomy, write the session memory, update MEMORY.md, update project files, commit locally, confirm. Do not skip steps or improvise the order. Never push, pull or fetch.

That is the whole command. It takes no arguments.
