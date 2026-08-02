- You're on a NixOS system
- Never search files/content recursively on /nix/store, /nix/store is just too big to search
- If you want to find a package for a specific file, use nix-locate
- If you cannot find a package, use `nix run nixpkgs#{packagename} -- ...` or `export PATH="$(nix build nixpkgs#{packagename})/bin:$PATH"`
- If you want to find a package for a command, use `nix-locate --minimal --at-root /bin/{command}`
- The following commands are available:
  - rg
  - fd
  - jq
  - node
  - deno
  - yq
  - git-absorb
  - ast-grep
  - gh
  - http
  - docker
  - psql
  - devenv

- Prefer using fixup commits when a change clearly needed to be in an earlier commit you made (using
 `git commit --fixup <commit-hash>`)
- Look for existing commits to know how to format commit messages


- Prefer long-form arguments over short-hands (--argument vs -a)
- Avoid uncommon abbreviations in code and text; prefer full words (for example: "notification" over
 "notif", "ServiceDaemon" over "sd"). Single-letter names are never acceptable.

- Read all skills that are related, instead of just one
- When you have multiple tasks, read the related skill before each task
