{
  "greetd-autologin-keyring" = import ./greetd-autologin-keyring.nix;
  suite-single-user = import ./suite-single-user;
  suite-nix-channels = import ./suite-nix-channels;
  home-manager = import ./home-manager.nix;
  wireguard = import ./wireguard.nix;
}
