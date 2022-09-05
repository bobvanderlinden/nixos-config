{pkgs}: {
  coin = pkgs.callPackage ./coin {};
  git-worktree-shell = pkgs.callPackage ./git-worktree-shell {};
  gnome-dbus-emulation-wlr = pkgs.callPackage ./gnome-dbus-emulation-wlr {};
}
