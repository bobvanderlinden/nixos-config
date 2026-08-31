{
  lib,
  pkgs,
  ...
}:
let
  settings = {
    display = {
      position = "bottom-left";
      margin_x = 20;
      margin_y = 180;
      timeout_ms = 2000;
      held_key_timeout_ms = 500;
      history_count = 4;
      show_held_keys = true;
    };

    appearance = {
      theme = "dark";
      font_size = 18;
      opacity = 1.0;
      corner_radius = 8;
    };

    behavior = {
      combine_modifiers = true;
      show_modifier_only = false;
      excluded_keys = [ ];
    };

    privacy.pause_on_apps = [
      { class = "Bitwarden"; }
      { class = "1password"; }
      { class = "org.keepassxc.KeePassXC"; }
    ];
  };

  toml = pkgs.formats.toml { };
in
{
  home.packages = [ pkgs.tapshow ];

  xdg.configFile."tapshow/config.toml".source = toml.generate "tapshow-config.toml" settings;

  # GTK loads this stylesheet after tapshow's application stylesheet. Keep the
  # keycaps visible but remove the opaque rectangle surrounding them.
  xdg.configFile."gtk-4.0/gtk.css".text = ''
    .overlay-container {
      background: transparent;
      border: none;
      box-shadow: none;
    }
  '';

  systemd.user.services.tapshow = {
    Unit = {
      Description = "Display pressed keys on screen";
      After = [ "hyprland-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      PartOf = [ "hyprland-session.target" ];
    };

    Service = {
      ExecStart = lib.getExe pkgs.tapshow;
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
