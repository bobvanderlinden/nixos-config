{
  writeShellApplication,
  gh,
  git,
}:
writeShellApplication {
  name = "gh-org-clone";
  text = builtins.readFile ./gh-org-clone.sh;
  runtimeInputs = [
    gh
    git
  ];
}
