{
  writeShellApplication,
  git,
  coreutils,
  jq,
  git-worktree-shell,
  direnv,
}:
writeShellApplication {
  name = "agent-worktree";
  text = builtins.readFile ./agent-worktree.sh;
  runtimeInputs = [
    git
    coreutils
    jq
    git-worktree-shell
    direnv
  ];
}
