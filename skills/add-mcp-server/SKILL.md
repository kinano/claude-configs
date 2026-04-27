---
name: add-mcp-server
description: Add an MCP server to the current project by creating or updating a project-level .mcp.json, .env, and .gitignore
model: haiku
---

# Add MCP Server to Current Project

Use this skill when the user wants to add an MCP server that should only be available in a specific repo or project — not globally.

1. Before touching any files, collect **all** required information upfront:
   - Which MCP server(s) to add (ask if not specified).
   - Server type: command-based (`command` + `args`) or HTTP/SSE (`url`).
   - All required env vars (API tokens, secrets, etc.) and their values — ask the user for any that aren't already defined (see step 3).

2. Locate the project root using `git rev-parse --show-toplevel`. Use that directory for all file operations. Check whether a `.mcp.json` already exists there — if so, read it to merge additions without clobbering existing servers.

3. Check whether a `.env` file exists at the project root. If it does, read it to identify which required env vars are already defined. Only ask the user for values that are genuinely missing. Do not read `.env` if it's blocked by permissions — just ask the user instead.

4. For any missing env var values collected in step 1: add them to `.env` (creating it if needed).

5. Write or update `.mcp.json` using `${VAR_NAME}` syntax to reference env vars — Claude Code expands these at runtime. Never hardcode secret values.

   Command-based server:
   ```json
   {
     "mcpServers": {
       "<server-name>": {
         "command": "<executable>",
         "args": ["<arg1>", "<arg2>"],
         "env": {
           "API_TOKEN": "${API_TOKEN}"
         }
       }
     }
   }
   ```

   HTTP/SSE server:
   ```json
   {
     "mcpServers": {
       "<server-name>": {
         "url": "https://example.com/mcp",
         "headers": {
           "Authorization": "Bearer ${API_TOKEN}"
         }
       }
     }
   }
   ```

6. `.mcp.json` is safe to commit because it only contains `${VAR_NAME}` references, never literal secrets. Ensure `.env` is in `.gitignore` — check and add it if missing, then let the user know.

7. Tell the user to restart their Claude Code session for the new server to take effect. A full restart is required — the `/mcp` command only lists servers, it does not reload them.

8. After restarting, the user should run `/mcp` to confirm the server appears in the list. If it doesn't show up, check for typos in the server name, verify the command is installed, and confirm all env vars are set correctly in `.env`.
