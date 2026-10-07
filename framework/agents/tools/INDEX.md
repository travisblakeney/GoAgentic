# Tools

Shared tool configuration for all agents. Per-tool reference files are in this directory. Agent-specific overrides live in each agent's `tools.md`.

## Available Tools

| Tool | Credential | Status | Reference | Description |
|------|-----------|--------|-----------|-------------|
| *(none yet)* | | | | Add a row per tool, with a reference file `agents/tools/<tool>.md`. See `.agents/agents-framework/agents/reference/tooling.md` § Adding a New Tool. |

**Credential types:**
- **User** — runs under {{PRINCIPAL}}'s own logged-in CLI session; the harness asks before each call that is not on its allow list. The only type this framework uses.
- **MCP** — an MCP server {{PRINCIPAL}} configured and pinned in the harness. No credentials in the workspace.

Agents never get their own accounts, tokens or keys (`reference/tooling.md` § Credentials).
