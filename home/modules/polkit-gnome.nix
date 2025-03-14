{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    literalExample
    mkIf
    ;
  cfg = config.services.polkit-gnome;
in
{
  options = {
    services.polkit-gnome = {
      enable = mkEnableOption "GNOME Policykit Agent";
      package = mkOption {
        type = types.package;
        default = pkgs.polkit_gnome;
        defaultText = literalExample "pkgs.polkit_gnome";
        description = ''
          GNOME Policykit package to use
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.polkit-gnome = {
      Unit = {
        Description = "GNOME PolicyKit Agent";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${cfg.package}/libexec/polkit-gnome-authentication-agent-1";
      };
    };
  };
}
