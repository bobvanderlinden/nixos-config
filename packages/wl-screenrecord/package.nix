{
  writeShellApplication,
  parallel,
  libnotify,
  slurp,
  wf-recorder,
  wl-clipboard-rs,
  xdg-utils,
}:
writeShellApplication {
  name = "wl-screenrecord";
  text = builtins.readFile ./wl-screenrecord.sh;
  runtimeInputs = [
    parallel
    libnotify
    slurp
    wf-recorder
    wl-clipboard-rs
    xdg-utils
  ];
}
