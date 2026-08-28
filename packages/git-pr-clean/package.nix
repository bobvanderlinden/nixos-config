{
  writeShellApplication,
  git,
  gh,
}:
writeShellApplication {
  name = "git-pr-clean";
  text = builtins.readFile ./git-pr-clean.sh;
  runtimeInputs = [
    git
    gh
  ];
}
