{ pkgs }:
let
  inherit (pkgs) callPackage;
in
{
  coin = callPackage ./coin { };
  git-worktree-shell = callPackage ./git-worktree-shell { };
  gnome-dbus-emulation-wlr = callPackage ./gnome-dbus-emulation-wlr { };
  immersed = callPackage ./immersed { };
  disable-firewall = callPackage ./disable-firewall { };
  xrdesktop = callPackage ./xrdesktop { };
  gxr = callPackage ./gxr { };
  gulkan = callPackage ./gulkan { };
  wxrd = callPackage ./wxrd { };
  wxrc = callPackage ./wxrc { };
}
