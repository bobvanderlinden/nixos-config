# Pi environments and worktrees

`agent-worktree` creates a worktree and starts `agent` there. For `agent` and
`pi`, the direnv extension loads the environment at session startup. Other
commands passed to `agent-worktree` still run through `direnv exec`.

Pi-subagents calls `worktree` for managed worktree paths and creation. The
pinned local package in `packages/pi-subagents` patches its native allocator;
Pi-subagents still owns handoff records and cleanup. Children start at the
parent's `HEAD` without fetching upstream or copying staged changes. A clean
source checkout is required. Use `worktree: false` explicitly for a child that
needs the current checkout, such as a review of uncommitted changes.

`worktree --root` selects the nearest `.worktrees` directory above the original
checkout, or `/tmp/worktrees/$UID` if none exists. Subagent worktrees live at
`<root>/<repository>/pi-worktree-<run>-<index>`. Creating a worktree from another
worktree keeps the original repository's name and root.

Both interactive and subagent worktrees use `worktree --prepare`:

- Copy local, untracked environment and agent configuration, including
  `.envrc.local`, `.env`, `.nix`, `.agents`, and `.pi`. Preserve tracked files
  from the selected base commit. Do not copy parent Pi tasks or sessions.
- Link `node_modules`, `.venv`, and `.cache` directories, including caches in
  tracked monorepo packages. Writes through these links affect the shared cache.
- Back up devenv's evaluation cache with SQLite's backup API. Do not share
  devenv service state, sockets, or generated shell scripts with absolute paths.

Direnv regenerates the child environment for its own directory. Nix's store
and download caches are already shared. Copying a parent direnv export or
sharing all of `.devenv` would retain paths and process state from the parent.
The setup hook reports copied and linked paths as synthetic, so Pi-subagents
removes them before capturing its handoff patch without deleting source files.

`subagents.defaultSubagentOnlyExtensions` loads `direnv.ts` in children,
including foreground children that do not discover ambient extensions. An
agent's explicit `subagentOnlyExtensions` list replaces this default. Agents
with such a list must include `direnv.ts` themselves. A capability policy that
denies extensions also prevents automatic direnv loading.

The extension awaits `direnv export json` during `session_start` and applies
its result to the process environment. It automatically allows blocked
`.envrc` files. Its `before_agent_start` hook tells the model whether loading
succeeded, even in headless sessions and agents with replacement system
prompts. Tool allowlists can hide `direnv_reload` without disabling these
lifecycle hooks. Agents should not source `.envrc` or start another development
shell when the environment is already loaded.

Tests:

```sh
node --test tests/worktree.test.mjs tests/agent-worktree.test.mjs tests/pi-direnv.test.mjs
```

The direnv tests run the extension's headless lifecycle with real direnv and an
isolated allow database. They do not make model requests. To also exercise the
built subagent allocator, set `WORKTREE_COMMAND` to the built `worktree` binary
and `PI_SUBAGENTS_PACKAGE` to the built package's
`lib/node_modules/pi-subagents` directory before running the tests.
