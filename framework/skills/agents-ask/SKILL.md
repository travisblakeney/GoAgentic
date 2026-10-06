---
name: agents-ask
description: 'Write a request for another agent in this workspace — a review, a fact, or a draft. Writes a self-contained request file into the target''s peer/ folder and prints the command the principal runs to have the target answer it. Never starts another agent itself. Same workspace only. Use /agents-ask <name> "<request>".'
---

# /agents-ask — Peer Request

You ask one agent in this workspace to do one bounded thing for the agent you currently are (or for the principal, if no agent is active). The full protocol is `.agents/agents-framework/agents/reference/peer.md`. Read it once, then follow it.

You **never start, prompt or drive another agent session yourself** — no terminal multiplexer, no headless CLI call, no background process. You write the request; the principal decides whether and when to run the target.

## Preconditions

1. Workspace root = current working directory; it must contain `agents/`. Glob `agents/<name>/context.md` or `agents/*/<name>/context.md` (case-insensitive). Not found, or `status: retired` → say so, suggest `/agents-list`, stop. **Never** look outside this root and never mention agents from other roots.
2. Caller = the agent currently active in this session, else `principal`.
3. The request must stay inside peer limits: the target may read and draft at ceiling **L3**. A request that needs the target to send, publish, push, buy, delete or contact anyone is not a peer request — tell the principal instead and stop.

## Steps

1. `date` → stamp `YYYY-MM-DD-HHMM`. Create `agents/<Target>/peer/` if missing. Write `agents/<Target>/peer/<stamp>-from-<caller>.md` with the frontmatter and `## Request` from peer.md (`status: open`). The request text must be self-contained: name every file, ID, and constraint the target needs, all as workspace paths. Do not rely on anything only this session knows. Do not paste secrets.
2. Print, as the last lines of your reply:

   ```
   Request written: agents/<Target>/peer/<file>
   To answer it, open a new session in this workspace and run:
     /agents-start <target> peer agents/<Target>/peer/<file>
   (Codex: $agents-start …)  When the reply is in, ask me to read it.
   ```

3. When the principal says the reply is in (or a later session finds the file `answered` / `needs-principal`), read the file, present the reply in ≤ 10 lines and any `Needs <principal>:` lines verbatim, then set `status: done` once the caller has used it.

## Rules

- One request per call. No chains (a peer session must not `/agents-ask`).
- Do not commit. The file is committed by the caller's session end.
- Do not add the exchange to any tracker unless the principal says so.
