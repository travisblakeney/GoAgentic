---
name: agents-close
description: 'End the current agent session, save its state, and then hand over to a fresh conversation. It is /agents-wrap followed by clearing the conversation. Run it from inside an active agent session; no name needed. Use /agents-wrap instead if you want to keep the conversation open after saving.'
---

# /agents-close — End the session and start fresh

`/agents-close` is `/agents-wrap` followed by a fresh conversation: it saves the session's state, then asks the principal to clear the conversation so the next session starts clean. The Session End Protocol persists everything to disk (tracker, memory, local commit), so nothing is lost by clearing.

## Procedure

1. **Wrap the session first.** Read `.agents/skills/agents-wrap/SKILL.md` and follow it exactly — identify the active agent and run the full eight-step Session End Protocol.
   - If `/agents-wrap` finds no active agent, stop as it says.
2. **Confirm the wrap fully succeeded**: the action tracker and session memory are written and, unless the workspace sets `commit: off`, the local commit (Session End Protocol step 7) reported success. If any step failed, stop and report it, so the unsaved work stays visible.
3. **Hand over.** As your final message, say one short line, e.g. "Session wrapped and committed locally. Clear the conversation now (`/clear` in Claude Code, or your CLI's new-chat command)." Do not try to run the clear command yourself.

It takes no arguments.
