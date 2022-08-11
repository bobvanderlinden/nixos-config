{
  pkgs,
  config,
  inputs,
  ...
}: let
  username = config.suites.single-user.user;
in {
  imports = [inputs.home-manager.nixosModules.home-manager];

  home-manager.verbose = true;
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."${username}".imports = [./../../home];
}
