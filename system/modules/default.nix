{
  suite-single-user = import ./suites/single-user.nix;
  suite-sway = import ./suites/sway.nix;
  suite-wayland = import ./suites/wayland.nix;
  suite-nix-channels = import ./suites/nix-channels.nix;
  home-manager = import ./home-manager.nix;
}
