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
  cfg = config.services.hyprpolkitagent;
in
{
  options = {
    services.hyprpolkitagent = {
      enable = mkEnableOption "Hyprland Policykit Agent";
      package = mkOption {
        type = types.package;
        default = pkgs.hyprpolkitagent;
        defaultText = literalExample "pkgs.hyprpolkitagent";
        description = ''
          Hyprland Policykit package to use
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.hyprpolkitagent = {
      Unit = {
        Description = "Hyprland PolicyKit Agent";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${cfg.package}/libexec/hyprpolkitagent";
      };
    };
  };
}
