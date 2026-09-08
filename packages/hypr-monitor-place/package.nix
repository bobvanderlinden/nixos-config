{
  writeShellApplication,
  hyprland,
  jq,
}:
writeShellApplication {
  name = "hypr-monitor-place";
  text = builtins.readFile ./hypr-monitor-place.sh;
  runtimeInputs = [
    hyprland
    jq
  ];
}
