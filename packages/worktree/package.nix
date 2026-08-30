{
  writeShellApplication,
  coreutils,
  direnv,
  gh,
  git,
  zoxide,
}:
writeShellApplication {
  name = "worktree";
  text = builtins.readFile ./worktree.sh;
  runtimeInputs = [
    coreutils
    direnv
    gh
    git
    zoxide
  ];
}
