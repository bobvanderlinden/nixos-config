{
  writeShellApplication,
  hyprland,
}:
writeShellApplication {
  name = "hypr-exec";
  text = builtins.readFile ./hypr-exec.sh;
  runtimeInputs = [ hyprland ];
}
