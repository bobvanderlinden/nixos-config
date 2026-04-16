{
  "greetd-autologin-keyring" = import ./greetd-autologin-keyring.nix;
  suite-single-user = import ./suites/single-user.nix;
  suite-nix-channels = import ./suites/nix-channels.nix;
  home-manager = import ./home-manager.nix;
  wireguard = import ./wireguard.nix;
}
