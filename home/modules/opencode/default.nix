{
  impurity,
  ...
}:
{
  imports = [
    ./direnv.nix
    ./secrets.nix
  ];

  programs.opencode = {
    enable = true;
    settings = {
      permission = {
        skill = "deny"; # Use custom 'skills' tool instead
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
          "/nix/store/**" = "allow";
          "~/.cache/uv/*" = "allow";
        };
      };
      mcp = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
        };
      };
    };
    tui.keybinds = {
      # Remove home/end from message scrolling so they only move the cursor
      # in the input buffer (input_buffer_home / input_buffer_end).
      messages_first = "ctrl+g";
      messages_last = "ctrl+alt+g";
    };
  };

  # Symlink the plugins and tools directories directly into XDG config.
  # Any edit to a plugin/tool file is picked up immediately without needing
  # switch-home (when impurity is enabled).
  xdg.configFile."opencode/plugins".source = impurity.link ./plugins;

  # We cannot use symlnks, because ts imports will use the real path.
  # xdg.configFile."opencode/tools".source = impurity.link ./tools;
}
