{
  suite-single-user = import ./suites/single-user.nix;
  suite-i3 = import ./suites/i3.nix;
  suite-sway = import ./suites/sway.nix;
  suite-wayland = import ./suites/wayland.nix;
  suite-nix-channels = import ./suites/nix-channels.nix;
  home-manager = import ./home-manager.nix;
  # hp-zbook-studio-g5 = import ./hp-zbook-studio-g5.nix;
  nvidia-vulkan = import ./nvidia-vulkan.nix;
}
