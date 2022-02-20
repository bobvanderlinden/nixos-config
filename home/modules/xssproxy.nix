{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options = {
    services.xssproxy = {
      enable = mkEnableOption "XSSProxy";
      package = mkOption {
        type = types.package;
        default = pkgs.xssproxy;
        defaultText = literalExample "pkgs.xssproxy";
        description = ''
          XSSProxy package to use
        '';
      };
    };
  };

  config = mkIf config.services.xssproxy.enable {
    systemd.user.services.xssproxy = {
      Unit = {
        Description = "forward freedesktop.org Idle Inhibition Service calls to Xss";
        After = ["graphical-session-pre.target"];
        PartOf = ["graphical-session.target"];
      };

      Install = {WantedBy = ["graphical-session.target"];};

      Service = {
        ExecStart = "${config.services.xssproxy.package}/bin/xssproxy";
      };
    };
  };
}
