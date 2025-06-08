{
  writeShellApplication,
  slurp,
  satty,
  grim,
  wl-clipboard-rs,
}:
writeShellApplication {
  name = "wl-screenshot";
  text = builtins.readFile ./wl-screenshot.sh;
  runtimeInputs = [
    slurp
    satty
    grim
    wl-clipboard-rs
  ];
}
