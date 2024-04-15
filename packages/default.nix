{ pkgs }:
let
  inherit (pkgs) callPackage;
in
rec {
  coin = callPackage ./coin { };
  git-worktree-shell = callPackage ./git-worktree-shell { };
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
  libinputsynth = callPackage ./libinputsynth {
    mutter = pkgs.gnome.mutter338;
  };
  gnome-shell-xrdesktop = pkgs.gnome.gnome-shell.overrideAttrs (oldAttrs: {
    src = pkgs.fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "xrdesktop";
      repo = "gnome-shell";
      rev = "d3594f643407c6fd1e8f4b50112833abf60433a1";
      hash = "sha256-IzmvqKrbeS2O/d2GlFCYXZOaUGj/5oYRYfhQyX63xxE=";
    };

    postPatch = ''
      patchShebangs src/data-to-c.pl

      # We can generate it ourselves.
      rm -f man/gnome-shell.1
    '';

    buildInputs = oldAttrs.buildInputs ++ (with pkgs; [
      vulkan-loader
    ]) ++ [
      xrdesktop
      gxr
      gulkan
      libinputsynth
    ];
  });
  sejda = callPackage ./sejda { };
}

