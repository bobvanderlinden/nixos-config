{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hyprwhspr-rs;
  jsonFormat = pkgs.formats.json { };
  runtimeInputs = [
    cfg.package
    pkgs.coreutils
    pkgs.ffmpeg
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.systemd
  ];
  # Launches hyprwhspr-rs with its runtime dependencies on PATH and the
  # provider API keys sourced from environmentFile. Started from Hyprland
  # (see home/modules/hypr/hyprland.lua) instead of a systemd user service.
  hyprwhspr-rs-session = pkgs.writeShellApplication {
    name = "hyprwhspr-rs-session";
    inherit runtimeInputs;
    text = ''
      ${lib.optionalString (cfg.environmentFile != null) ''
        if [ -r ${lib.escapeShellArg cfg.environmentFile} ]; then
          set -a
          # shellcheck source=/dev/null
          . ${lib.escapeShellArg cfg.environmentFile}
          set +a
        fi
      ''}
      exec hyprwhspr-rs
    '';
  };
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
    home.packages = [
      cfg.package
      hyprwhspr-rs-session
    ];

    xdg.configFile."hyprwhspr-rs/config.jsonc".source =
      jsonFormat.generate "hyprwhspr-rs-config.json" cfg.settings;

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
