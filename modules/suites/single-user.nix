{
  config,
  lib,
  ...
}:
with lib; {
  options = {
    suites.single-user = {
      enable = mkEnableOption "Single-user suite";
      user = mkOption {
        type = types.str;
        description = ''
          The name of the single user for the machine.
        '';
      };
    };
  };

  config = let
    cfg = config.suites.single-user;
  in
    mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.user != null;
          message = "suites.single-user.enable requires suites.single-user.user to be set.";
        }
      ];
      users.users."${cfg.user}" = {
        uid = 1000;
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "network"
          "uucp"
          "dialout"
          "vboxusers"
          "networkmanager"
          "docker"
          "audio"
          "video"
          "input"
          "sudo"
        ];
        useDefaultShell = true;
      };

      services.xserver.displayManager.autoLogin.user = cfg.user;
    };
}
