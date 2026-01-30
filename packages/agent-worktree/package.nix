{
  writeShellApplication,
  git,
  coreutils,
  git-worktree-shell,
  claude-code,
  direnv,
}:
writeShellApplication {
  name = "agent-worktree";
  text = builtins.readFile ./agent-worktree.sh;
  runtimeInputs = [
    git
    coreutils
    git-worktree-shell
    claude-code
    direnv
  ];
}
