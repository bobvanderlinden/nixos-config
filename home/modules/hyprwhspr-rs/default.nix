{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hyprwhspr-rs;
  jsonFormat = pkgs.formats.json { };
  servicePath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.ffmpeg
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.systemd
  ];
  serviceSbinPath = lib.makeSearchPath "sbin" [
    pkgs.coreutils
    pkgs.ffmpeg
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.systemd
  ];
in
{
  options.hyprwhspr-rs = {
    enable = lib.mkEnableOption "hyprwhspr-rs desktop dictation";

    package = lib.mkPackageOption pkgs "hyprwhspr-rs" { };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "${config.home.homeDirectory}/.config/hyprwhspr-rs/env";
      defaultText = lib.literalExpression ''"${config.home.homeDirectory}/.config/hyprwhspr-rs/env"'';
      example = "/path/to/hyprwhspr-rs.env";
      description = "File containing provider API keys for hyprwhspr-rs.";
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "Settings written to hyprwhspr-rs config.jsonc.";
    };

    hyprland = {
      enable = lib.mkEnableOption "Hyprland keybinding integration for hyprwhspr-rs";

      holdKey = lib.mkOption {
        type = lib.types.str;
        default = "$mod, V";
        example = "$mod ALT, D";
        description = "Hyprland keybinding prefix used for hold-to-talk recording with hyprwhspr-rs.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."hyprwhspr-rs/config.jsonc".source =
      jsonFormat.generate "hyprwhspr-rs-config.json" cfg.settings;

    systemd.user.services.hyprwhspr-rs = {
      Unit = {
        Description = "Native speech-to-text voice dictation for Hyprland";
        After = [
          "graphical-session.target"
          "pipewire.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        Environment = [ "PATH=${servicePath}:${serviceSbinPath}" ];
      };
    };

    wayland.windowManager.hyprland.settings.bind = lib.mkIf cfg.hyprland.enable (
      lib.mkAfter [
        "${cfg.hyprland.holdKey}, exec, ${lib.getExe cfg.package} record start"
      ]
    );

    wayland.windowManager.hyprland.settings.bindr = lib.mkIf cfg.hyprland.enable (
      lib.mkAfter [
        "${cfg.hyprland.holdKey}, exec, ${lib.getExe cfg.package} record stop"
      ]
    );
  };
}
