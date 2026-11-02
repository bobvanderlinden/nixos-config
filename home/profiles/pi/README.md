# Pi environments and worktrees

## Nono sandbox

`programs.nono.pi.enable` wraps both `pi` and `pi-bolt` with
[nono](https://nono.sh). The module is `home/modules/nono/default.nix`.
The generated profile is also available at `~/.config/nono/profiles/pi.json`;
the launcher uses its immutable Nix store copy.

The project and Pi state are writable. Ancestor instructions and skill
directories are readable without exposing sibling projects. The launcher
refuses `/`, `/home`, and your home directory as workspaces. Start it from
the smallest project directory you need. Access to worktrees or shared virtual
environments outside that directory needs an additional explicit grant.

Patched Determinate Nix is first on PATH inside the sandbox. The local
`patches/nix-directory-opath.patch` fixes Nix 2.35 opening `/` for reading
during impure evaluation under Landlock. See
[#16703](https://github.com/NixOS/nix/issues/16703). The system configuration
also selects this patched Nix; the Determinate Nixd supervisor is unchanged.

Pathname Unix sockets are denied unless explicitly granted. The profile grants
the Nix daemon, rootless Docker, and 1Password CLI/app sockets. Direct 1Password
desktop authentication still fails because `no_new_privs` suppresses the CLI's
setgid group change. Those socket grants do not fix it. Credential injection
or a host-side broker is needed before this can replace the current workflow.
It does not grant the session D-Bus, SSH agent, or Wayland sockets. Existing `DOCKER_HOST` values
are preserved, but a non-default socket needs its own profile grant.

These compatibility exceptions limit the protection:

- Docker can ask its unsandboxed daemon to mount files outside the project.
  Rootless Docker prevents host-root access, not access to your own home files.
- `op` can retrieve credentials you authorize. Secrets already in the environment
  or project files are also accessible. Network access is unrestricted.
- Pi state is shared and writable, including extensions and authentication state.
  This allows persistence across sessions. It is not a disposable agent identity.
- MCP servers and other external command brokers can perform actions outside
  the sandbox. Do not treat their tools as sandboxed child processes.
- `pi-web` embeds Pi through its SDK and is **not** sandboxed by this CLI wrapper.
  Other launchers using a raw store path also bypass it.

The profile deliberately avoids granting all of `~/.cache`, the runtime
directory, or your home directory. Do not add those broad grants to resolve a
single permission error. A Docker-free profile with isolated Pi state would
provide a stronger boundary, but would change the current workflow.

## Environments and worktrees

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
