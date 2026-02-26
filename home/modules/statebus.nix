{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  options = {
    services.statebus = {
      enable = mkEnableOption "statebus ndjson state pub/sub daemon";

      package = mkOption {
        type = types.package;
        default = pkgs.statebus;
        defaultText = literalExpression "pkgs.statebus";
        description = "statebus package to use.";
      };

      publishSocket = mkOption {
        type = types.str;
        default = "%t/statebus-pub.sock";
        description = ''
          Path to the Unix socket that publishers connect to.
          %t is expanded by systemd to $XDG_RUNTIME_DIR.
        '';
      };

      subscribeSocket = mkOption {
        type = types.str;
        default = "%t/statebus-sub.sock";
        description = ''
          Path to the Unix socket that subscribers connect to.
          %t is expanded by systemd to $XDG_RUNTIME_DIR.
        '';
      };
    };
  };

  config = mkIf config.services.statebus.enable {
    systemd.user.services.statebus = {
      Unit = {
        Description = "statebus — ndjson state pub/sub daemon";
        After = [ "default.target" ];
      };

      Install = {
        WantedBy = [ "default.target" ];
      };

      Service = {
        ExecStart = "${config.services.statebus.package}/bin/statebus --publish ${config.services.statebus.publishSocket} --subscribe ${config.services.statebus.subscribeSocket}";
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
  };
}
