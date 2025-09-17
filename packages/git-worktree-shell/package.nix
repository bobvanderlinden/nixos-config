{
  writeShellApplication,
  git,
  coreutils,
}:
writeShellApplication {
  name = "git-worktree-shell";
  text = builtins.readFile ./git-worktree-shell.sh;
  runtimeInputs = [
    git
    coreutils
  ];
}
