{
  impurity,
  ...
}:
{
  imports = [
    ./secrets.nix
  ];

  programs.opencode = {
    enable = true;
    settings = {
      permission = {
        websearch = "allow";
        webfetch = "allow";
        bash = {
          "systemctl suspend" = "allow";
          "git *" = "allow";
          "gh *" = "allow";
          "find *" = "allow";
          "grep *" = "allow";
          "curl *" = "allow";
        };
        read = {
          "/nix/store/*" = "allow";
          "~/.cache/uv/*" = "allow";
        };
      };
      mcp = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
        };
      };
      keybinds = {
        # Remove home/end from message scrolling so they only move the cursor
        # in the input buffer (input_buffer_home / input_buffer_end).
        messages_first = "ctrl+g";
        messages_last = "ctrl+alt+g";
      };
    };
  };

  # Symlink the plugins directory directly into XDG config.
  # Any edit to a plugin file is picked up immediately without needing
  # switch-home (when impurity is enabled).
  xdg.configFile."opencode/plugins".source = impurity.link ./plugins;
}
