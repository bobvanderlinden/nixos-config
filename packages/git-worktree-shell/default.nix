{ writeShellApplication, git }:
writeShellApplication {
  name = "git-worktree-shell";
  text = builtins.readFile ./git-worktree-shell.sh;
  runtimeInputs = [ git ];
}
