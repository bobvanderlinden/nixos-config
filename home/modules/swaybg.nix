{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    escapeShellArgs
    mapAttrsToList
    flatten
    optionals
    types
    ;
  cfg = config.programs.swaybg;
  outputModule = types.submodule {
    options = {
      mode = lib.mkOption {
        type = types.nullOr (
          types.enum [
            "stretch"
            "fill"
            "fit"
            "center"
            "tile"
            "solid_color"
          ]
        );
        default = null;
        example = "center";
        description = "Scaling mode for images: stretch, fill, fit, center, or tile. Use the additional mode solid_color to display only the background color, even if a background image is specified.";
      };
      color = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "#000000";
        description = "Set the background color.";
      };
      image = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/path/to/image.png";
        description = "Path to the image file to use as the background.";
      };
    };
  };
in
{
  options = {
    programs.swaybg = {
      enable = lib.mkEnableOption "swaybg";
      target = lib.mkOption {
        type = types.str;
        default = "graphical-session.target";
        example = "sway-session.target";
      };
      package = lib.mkOption {
        type = types.package;
        default = pkgs.swaybg;
      };

      outputs = lib.mkOption {
        type = types.attrsOf outputModule;
        default = { };
        example = {
          "*" = {
            mode = "center";
            color = "#000000";
            image = "/path/to/image.png";
          };
          "DP-1" = {
            mode = "center";
            color = "#000000";
            image = "/path/to/image.png";
          };
        };
      };

    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.swaybg = {
      Unit = {
        Description = "swaybg";
        PartOf = [ cfg.target ];
        After = [ cfg.target ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${cfg.package}/bin/swaybg ${
          escapeShellArgs (
            flatten (
              mapAttrsToList (
                output:
                {
                  mode,
                  color,
                  image,
                }:
                (
                  [
                    "--output"
                    output
                  ]
                  ++ (optionals (mode != null) [
                    "--mode"
                    mode
                  ])
                  ++ (optionals (color != null) [
                    "--color"
                    color
                  ])
                  ++ (optionals (image != null) [
                    "--image"
                    image
                  ])
                )
              ) cfg.outputs
            )
          )
        }";
      };
      Install = {
        WantedBy = [ cfg.target ];
      };
    };
  };
}
