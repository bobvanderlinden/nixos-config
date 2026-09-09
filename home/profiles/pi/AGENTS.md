- The following commands are available:
  - rg
  - fd
  - jq
  - python3
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
  - direnv

- Most projects use direnv and have a .envrc file. You do not need to load this, because these files are loaded into your environment automatically.

- Prefer using fixup commits when a change clearly needed to be in an earlier commit you made (using
 `git commit --fixup <commit-hash>`)
- Look for existing commits to know how to format commit messages


- Prefer long-form arguments over short-hands (--argument vs -a)
- Avoid uncommon abbreviations in code and text; prefer full words (for example: "notification" over
 "notif", "ServiceDaemon" over "sd"). Single-letter names are never acceptable.

- Read all skills that are related, instead of just one
- When you have multiple tasks, read the related skill before each task

- Always refer to GitHub issues or PRs using links: [#123](https://github.com/{owner}/{repo}/pull/123)
