{ pkgs }:
let
  inherit (pkgs) callPackage;
in
{
  coin = callPackage ./coin { };
  git-worktree-shell = callPackage ./git-worktree-shell { };
  wl-screenrecord = callPackage ./wl-screenrecord { };
  swaylock-fprintd = callPackage ./swaylock-fprintd { };
  sway-open = callPackage ./sway-open { };
  lazy-desktop = callPackage ./lazy-desktop { };
  immersed = callPackage ./immersed { };
  disable-firewall = callPackage ./disable-firewall { };
  xrdesktop = callPackage ./xrdesktop { };
  gxr = callPackage ./gxr { };
  gulkan = callPackage ./gulkan { };
  wxrd = callPackage ./wxrd { };
  wxrc = callPackage ./wxrc { };
  alvr = callPackage ./alvr { };
  x3d = callPackage ./x3d { };
  stardust-xr = callPackage ./stardust-xr { };
  libstardustxr = callPackage ./libstardustxr { };
  stereo-kit = callPackage ./stereo-kit { };
  sk_gpu = callPackage ./sk_gpu { };
  reactphysics3d = callPackage ./reactphysics3d { };
  libinputsynth = callPackage ./libinputsynth { mutter = pkgs.mutter338; };
  sejda = callPackage ./sejda { };
}
