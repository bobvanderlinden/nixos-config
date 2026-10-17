{
  writeShellApplication,
  coreutils,
  direnv,
  gh,
  git,
  python3,
  zoxide,
}:
writeShellApplication {
  name = "worktree";
  text = builtins.replaceStrings [
    ''$(dirname "''${BASH_SOURCE[0]}")/worktree-prepare.py''
  ] [
    "${./worktree-prepare.py}"
  ] (builtins.readFile ./worktree.sh);
  runtimeInputs = [
    coreutils
    direnv
    gh
    git
    python3
    zoxide
  ];
}
