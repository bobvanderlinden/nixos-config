{
  pkgs,
  config,
  inputs,
  ...
}:
let
  username = config.suites.single-user.user;
in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager.verbose = true;
  home-manager.useGlobalPkgs = true;
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = { inherit inputs; };
  environment.pathsToLink = [
    "/share/applications"
    "/share/wayland-sessions"
  ];
  home-manager.users."${username}".imports = [ ./../../home ];
}
