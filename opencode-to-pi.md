# OpenCode to Pi migration plan

## Current state

- Pi is already installed/configured enough to run.
- Pi config exists at `~/.pi/agent/settings.json`.
- Pi auth exists at `~/.pi/agent/auth.json` and is configured for GitHub Copilot.
- Current Pi defaults:
  - provider: `github-copilot`
  - model: `gpt-5.5`
  - thinking level: `medium`
- OpenCode config exists at `~/.config/opencode/`.
- OpenCode global/project config mostly contains permissions and MCP configuration.
- OpenCode skills are already in Agent Skills-style directories with `SKILL.md`, so they can be reused by Pi.

## Goals

1. Preserve global coding instructions.
2. Reuse existing OpenCode skills in Pi.
3. Decide what to do with OpenCode permissions, MCP, and web tools.
4. Avoid unnecessary session conversion unless a specific session is needed.
5. Keep the migration small and reversible.

## 1. Migrate global instructions

OpenCode instructions currently appear to be in:

```text
~/.config/opencode/AGENTS.md.backup
```

Pi reads global instructions from:

```text
~/.pi/agent/AGENTS.md
```

Migration command:

```bash
mkdir -p ~/.pi/agent
cp ~/.config/opencode/AGENTS.md.backup ~/.pi/agent/AGENTS.md
```

Notes:

- Pi automatically reads `AGENTS.md` and `CLAUDE.md` from projects and parent directories.
- Existing project-level instruction files probably do not need to be moved.

## 2. Reuse OpenCode skills

Existing OpenCode skills:

```text
~/.config/opencode/skill/aidbox/SKILL.md
~/.config/opencode/skill/commit/SKILL.md
~/.config/opencode/skill/medikit/SKILL.md
~/.config/opencode/skill/medikit-create-pull-request/SKILL.md
~/.config/opencode/skill/medikit-invite-reviewer/SKILL.md
~/.config/opencode/skill/review/SKILL.md
~/.config/opencode/skill/typescript/SKILL.md
```

Pi can load these directly by adding the OpenCode skill directory to Pi settings.

Edit:

```text
~/.pi/agent/settings.json
```

Add:

```json
"skills": ["~/.config/opencode/skill"]
```

Example resulting settings:

```json
{
  "lastChangelogVersion": "0.80.2",
  "theme": "dark",
  "defaultProvider": "github-copilot",
  "defaultModel": "gpt-5.5",
  "defaultThinkingLevel": "medium",
  "skills": ["~/.config/opencode/skill"]
}
```

Alternative: copy skills into Pi's native global skill directory:

```bash
mkdir -p ~/.pi/agent/skills
cp -a ~/.config/opencode/skill/* ~/.pi/agent/skills/
```

Recommendation: use the settings-based path first. It avoids duplication and keeps the migration reversible.

## 3. Remove/ignore the custom OpenCode skills tool

OpenCode custom tool:

```text
~/.config/opencode/tools/skills.ts
```

Pi does not need this. Pi has native skill discovery and exposes skills as `/skill:name` commands.

Examples:

```text
/skill:typescript
/skill:review
/skill:medikit
/skill:commit
```

No migration needed for this tool unless it has behavior beyond loading skills.

## 4. Handle OpenCode permissions

OpenCode config contains permission rules, for example:

```json
{
  "permission": {
    "bash": {
      "curl *": "allow",
      "find *": "allow",
      "gh *": "allow",
      "git *": "allow",
      "grep *": "allow",
      "systemctl suspend": "allow"
    },
    "external_directory": {
      "/nix/store/**": "allow"
    },
    "read": {
      "/nix/store/**": "allow",
      "~/.cache/uv/*": "allow"
    },
    "skill": "deny",
    "webfetch": "allow",
    "websearch": "allow"
  }
}
```

Pi does not use OpenCode-style permission JSON. Options:

### Option A: Accept Pi defaults

Pi default tools include:

- `read`
- `write`
- `edit`
- `bash`
- `grep`
- `find`
- `ls`

This is the simplest migration.

### Option B: Use tool allowlists per invocation

Read-only/review mode:

```bash
pi --tools read,grep,find,ls
```

Disable specific tools:

```bash
pi --exclude-tools bash
```

Disable all built-in tools:

```bash
pi --no-builtin-tools
```

### Option C: Write a Pi permission-gate extension

Use a Pi extension to block or confirm dangerous tool calls.

Target behavior to consider:

- Confirm dangerous bash commands like `rm -rf`, `sudo`, destructive `git`, etc.
- Block or confirm writes to protected paths.
- Optionally allow reads under `/nix/store/**` and `~/.cache/uv/*` explicitly.
- Optionally warn before commands outside an allowlist.

This is the closest equivalent to OpenCode permissions.

Potential file:

```text
~/.pi/agent/extensions/permission-gate.ts
```

Pi extension APIs to use:

- `pi.on("tool_call", ...)`
- `ctx.ui.confirm(...)`
- `isToolCallEventType(...)`

## 5. Replace MCP usage

OpenCode global config includes Context7 MCP:

```json
"mcp": {
  "context7": {
    "type": "remote",
    "url": "https://mcp.context7.com/mcp"
  }
}
```

Pi core does not include MCP support.

Options:

1. Replace Context7 with a Pi skill or package.
2. Write/install a Pi extension that implements MCP support.
3. Use `bash`/CLI tools for documentation lookup and describe the workflow in a skill.
4. Skip MCP initially and only reintroduce it if missed.

Recommendation: skip MCP for the initial migration, then add a targeted Pi extension/skill if needed.

## 6. Replace webfetch/websearch

OpenCode has `webfetch` and `websearch` permissions. Pi core does not ship built-in web fetch/search tools.

Options:

1. Use `bash` with `curl`, `gh`, or project-specific CLIs.
2. Install a Pi package/skill for web search.
3. Write a small extension wrapping a preferred search/fetch provider.

Recommendation: start with `bash`/`curl` and add a proper search skill/package later if needed.

## 7. TUI keybindings

OpenCode TUI config:

```json
{
  "keybinds": {
    "messages_first": "ctrl+g",
    "messages_last": "ctrl+alt+g"
  }
}
```

Pi keybindings live in:

```text
~/.pi/agent/keybindings.json
```

There is no direct built-in Pi equivalent for `messages_first` / `messages_last` in the current keybinding list.

Also, Pi uses `ctrl+g` for opening the external editor by default.

Recommendation: do not migrate these initially. If message navigation is important, implement it as a Pi extension later.

## 8. Project-level OpenCode config

Several projects contain `opencode.json` files. Most appear to contain only:

- `$schema`
- `permission`
- `mcp`

Pi project settings live at:

```text
.pi/settings.json
```

Because Pi does not directly understand OpenCode permissions or MCP config, do not blindly convert these files.

For each project:

1. Keep existing `AGENTS.md` and/or `CLAUDE.md`; Pi reads them automatically.
2. Only create `.pi/settings.json` if the project needs Pi-specific settings.
3. Only migrate permission/MCP behavior if it is actively needed.

## 9. Sessions

Pi sessions are stored as JSONL under:

```text
~/.pi/agent/sessions/
```

OpenCode sessions/databases are under:

```text
~/.local/state/opencode
~/.local/share/opencode
```

Do not attempt bulk session conversion initially.

If a specific OpenCode session is needed:

1. Export it from OpenCode if possible.
2. Import relevant context manually into Pi.
3. Or summarize the old session and start a new Pi session with the summary.

## Minimal migration steps

Run:

```bash
mkdir -p ~/.pi/agent
cp ~/.config/opencode/AGENTS.md.backup ~/.pi/agent/AGENTS.md
```

Edit `~/.pi/agent/settings.json` and add:

```json
"skills": ["~/.config/opencode/skill"]
```

Then test:

```bash
pi
```

Inside Pi, test skills:

```text
/skill:typescript
/skill:review
/skill:medikit
```

## Recommended next steps

1. Add OpenCode skill directory to Pi settings.
2. Copy global instructions to `~/.pi/agent/AGENTS.md`.
3. Run Pi in a few common repositories and verify startup context.
4. Decide whether a permission-gate extension is needed.
5. Defer MCP and web search migration until there is a concrete need.
6. Leave OpenCode config/sessions in place until Pi workflow is proven.

## Repository migration inventory

This section tracks the remaining OpenCode references in this repository and the changes needed to remove or replace them.

Inventory commands used:

```bash
rg --hidden --glob '!/.git/**' -n -i 'opencode' .
git grep -n -i opencode
find . -path ./.git -prune -o \( -iname '*opencode*' -o -name '.opencode' \) -print | sort
```

Current findings:

- Tracked OpenCode module files exist under `home/modules/opencode/`.
- `home/default.nix` imports `./modules/opencode`.
- `packages/agent` wraps `opencode` directly.
- `packages/agent-worktree` still links OpenCode project config and injects context through `OPENCODE_CONFIG_CONTENT`.
- Several comments, docs, and helper packages mention OpenCode-specific plugins/behavior.
- No tracked `opencode.json` or `.opencode` files were found by filename in this repo.
- `opencode-to-pi.md` itself is currently an untracked migration note.

### A. Replace the Home Manager OpenCode module

Files:

```text
home/default.nix
home/modules/opencode/default.nix
home/modules/opencode/direnv.nix
home/modules/opencode/secrets.nix
home/modules/opencode/plugins/direnv.ts
home/modules/opencode/plugins/notify.js
home/modules/opencode/plugins/secret-filter.ts
home/modules/opencode/plugins/session-status.js
home/modules/opencode/plugins/systemd-inhibit.js
home/modules/opencode/tools/skills.ts
```

Needed changes:

1. Decide whether to remove `home/modules/opencode/` outright or replace it with `home/modules/pi/`.
2. Change `home/default.nix` import from:

   ```nix
   ./modules/opencode
   ```

   to either:

   ```nix
   ./modules/pi
   ```

   or remove the import if Pi is configured outside Home Manager.

3. Move reusable skill content out of `programs.opencode.skills.*`:

   - `home/modules/opencode/direnv.nix` -> Pi skill directory such as `~/.pi/agent/skills/direnv/SKILL.md` or a managed repo path linked into Pi settings.
   - `home/modules/opencode/secrets.nix` -> Pi skill directory such as `~/.pi/agent/skills/secrets/SKILL.md` or a managed repo path linked into Pi settings.

4. Keep the `home.packages` additions from `secrets.nix` somewhere if the skills remain useful:

   ```nix
   pkgs.generate-secret
   pkgs.generate-password
   ```

5. Drop OpenCode-only settings that have no direct Pi equivalent:

   - `programs.opencode.settings.permission`
   - `programs.opencode.settings.mcp`
   - `programs.opencode.tui.keybinds.messages_first`
   - `programs.opencode.tui.keybinds.messages_last`

6. If needed, replace OpenCode permission behavior with a Pi extension using `pi.on("tool_call", ...)`.
7. If needed, replace Context7 MCP with a Pi extension/package/skill later.
8. Remove `home/modules/opencode/tools/skills.ts`; Pi has native skill discovery and `/skill:name` commands.

### B. Port or remove OpenCode plugins

OpenCode plugin files:

```text
home/modules/opencode/plugins/direnv.ts
home/modules/opencode/plugins/notify.js
home/modules/opencode/plugins/secret-filter.ts
home/modules/opencode/plugins/session-status.js
home/modules/opencode/plugins/systemd-inhibit.js
```

Recommended handling:

1. `direnv.ts`
   - Current code imports from a local OpenCode-specific project:

     ```ts
     /home/bob.vanderlinden/projects/opencode-direnv/src/index.ts
     ```

   - Replace with a Pi extension only if Pi needs explicit direnv loading beyond `direnv exec . pi` in `agent-worktree`.

2. `notify.js`
   - Port to Pi if desktop notifications on agent idle/error/permission remain desired.
   - Likely Pi events/API to use:
     - `agent_end`
     - `tool_call` plus confirmation/blocking flows for permission-like prompts
     - `ctx.ui.notify(...)` for in-TUI notifications, or `hypr-notify` via a spawned command for desktop notifications
   - Change notification text/app name from `OpenCode` to `Pi` or `Agent`.

3. `secret-filter.ts`
   - Port to a Pi extension if generated secrets should continue to be redacted from tool output.
   - Pi event/API to use:
     - `pi.on("tool_result", ...)`
   - Keep the current secret pattern if compatible:

     ```ts
     /SeCrEt-[a-zA-Z0-9\-_?!@&*+]+/g
     ```

4. `session-status.js`
   - Port to a Pi extension if QuickShell/statebus should continue showing live agent state.
   - Pi events to consider:
     - `session_start`
     - `session_shutdown`
     - `agent_start`
     - `agent_end`
     - `tool_call`
     - `message_update`
   - Publish the same statebus schema if possible:

     ```json
     { "type": "update", "key": "...", "windowAddress": "...", "state": "...", "title": "...", "todos": [] }
     { "type": "remove", "key": "..." }
     ```

5. `systemd-inhibit.js`
   - Port to a Pi extension if sleep should be inhibited while the agent is busy.
   - Pi events to consider:
     - acquire lock on `agent_start`
     - release lock on `agent_end` and `session_shutdown`
   - Change `systemd-inhibit --who=opencode` to `--who=pi` or `--who=agent`.

### C. Update the `agent` wrapper package

Files:

```text
packages/agent/agent.sh
packages/agent/package.nix
```

Current behavior:

```bash
exec opencode "$@"
```

Needed changes:

1. Change wrapper to run Pi:

   ```bash
   exec pi "$@"
   ```

2. Change `packages/agent/package.nix` dependency from `opencode` to the Pi package available in this flake/nixpkgs.
3. Verify `agent` still appears in `home.packages` through `home/default.nix`.

### D. Update `agent-worktree`

Files:

```text
packages/agent-worktree/agent-worktree.sh
packages/agent-worktree/package.nix
```

OpenCode-specific behavior:

```bash
--link .opencode
--link opencode.json
EXISTING_CONFIG_CONTENT="${OPENCODE_CONFIG_CONTENT:-{}}"
export OPENCODE_CONFIG_CONTENT
OPENCODE_CONFIG_CONTENT="$(printf '%s' "$EXISTING_CONFIG_CONTENT" | jq --arg path "$CONTEXT_FILE" '.instructions += [$path]')"
```

Needed changes:

1. Replace OpenCode project config links:

   ```bash
   --link .opencode
   --link opencode.json
   ```

   with Pi project config links if desired:

   ```bash
   --link .pi
   --link AGENTS.md
   --link CLAUDE.md
   ```

   `AGENTS.md` and `CLAUDE.md` are already linked today.

2. Replace context injection through `OPENCODE_CONFIG_CONTENT`.

   Options:

   - Prefer a temporary `AGENTS.md`/context file copied or linked into the worktree if `git-worktree-shell` supports it.
   - Pass an explicit Pi option if one exists for extra context/instructions.
   - Add a small Pi extension that reads a dedicated environment variable such as `PI_CONTEXT_FILE` and injects it in `before_agent_start`.

3. Keep `direnv exec . "${COMMAND[@]}"` unless the future Pi direnv extension makes it unnecessary.
4. `jq` may no longer be needed in `packages/agent-worktree/package.nix` after removing `OPENCODE_CONFIG_CONTENT` manipulation.

### E. Update state/status consumers and helper docs

Files:

```text
home/modules/quickshell/AgentState.qml
packages/agents-idle/agents-idle.py
packages/hypr-notify/README.md
system/configuration.nix
```

Needed changes:

1. `home/modules/quickshell/AgentState.qml`
   - Update comments from `opencode session-status plugin` to `Pi session-status extension` or generic `agent session-status extension`.
   - Keep the statebus schema if the Pi extension preserves it.

2. `packages/agents-idle/agents-idle.py`
   - Update docstring from `opencode agents` to `AI agents` or `Pi agents`.
   - Confirm state names remain compatible with the new Pi status extension, especially `busy` and `retry`.

3. `packages/hypr-notify/README.md`
   - Replace OpenCode notify plugin references with Pi notify extension references.

4. `system/configuration.nix`
   - Update suspend comment from `opencode holds a sleep inhibitor` to `the agent/Pi holds a sleep inhibitor` after the Pi inhibit extension exists.

### F. Update secret generator comments

Files:

```text
packages/generate-password/generate-password.sh
packages/generate-secret/generate-secret.sh
```

Needed changes:

- Replace `opencode secret-filter plugin` comments with `agent secret-filter extension` or `Pi secret-filter extension`.
- Keep the `SeCrEt-` prefix and character set if the Pi `tool_result` redaction extension uses the same pattern.

### G. Remove or archive the OpenCode migration note

File:

```text
opencode-to-pi.md
```

Options:

1. Keep it temporarily as the migration tracker.
2. Commit it under a docs path, for example `docs/opencode-to-pi.md`.
3. Delete it after the migration is complete.

### H. Validation checklist

After implementing the repository changes:

```bash
rg --hidden --glob '!/.git/**' -n -i 'opencode' .
git grep -n -i opencode
nix flake check
nix run .#switch-home
```

Also verify manually:

1. `agent --version` or `agent` starts Pi.
2. `agent-worktree <project>` starts Pi in a temporary worktree.
3. Pi can load the migrated skills with `/skill:direnv`, `/skill:secrets`, and the existing reused skills.
4. If ported, desktop notifications still fire when an agent finishes or needs attention.
5. If ported, QuickShell still shows active agent status.
6. If ported, sleep inhibition is active only while Pi is working.
7. If ported, generated `SeCrEt-*` values are redacted from tool output.
