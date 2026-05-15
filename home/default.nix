{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mapAttrsToList;

  hyprlandSessionTarget = "wayland-session@hyprland.desktop.target";

  backgroundColor = "1a1b26";
  wallpaperSvg = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/4ad062cee62116f6055e2876e9638e7bb399d219/logo/nix-snowflake-colours.svg";
    hash = "sha256-43taHBHoFJbp1GrwSQiVGtprq6pBbWcKquSTTM6RLrI=";
  };
  wallpaperPng = pkgs.runCommand "nix-snowflake.png" { } ''
    ${pkgs.resvg}/bin/resvg ${wallpaperSvg} $out
  '';

  editor = pkgs.writeShellScriptBin "editor" ''
    code "$@" > /dev/null 2>&1 &
    disown
  '';

  terminal = pkgs.writeShellScriptBin "terminal" ''
    ghostty --working-directory="$(pwd)" > /dev/null 2>&1 &
    disown
  '';

  reassign-workspace = pkgs.writeShellScriptBin "reassign-workspace" ''
    target=$1
    current=$(${lib.getExe' pkgs.hyprland "hyprctl"} activeworkspace -j | ${lib.getExe pkgs.jq} --raw-output '.id')
    ${lib.getExe' pkgs.hyprland "hyprctl"} clients -j \
      | ${lib.getExe pkgs.jq} --raw-output --argjson current "$current" \
          '.[] | select(.workspace.id == $current) | .address' \
      | while read -r address; do
          ${lib.getExe' pkgs.hyprland "hyprctl"} dispatch movetoworkspacesilent "$target,address:$address"
        done
    ${lib.getExe' pkgs.hyprland "hyprctl"} dispatch workspace "$target"
  '';

  vscode-wrapper = pkgs.writeShellScriptBin "code" ''
    # Disable any custom node options that some projects might have.
    # These conflict with node inside vscode.
    export NODE_OPTIONS=""

    # Open files in the vscode instance on the current workspace.
    # Otherwise, open a new instance on the current workspace.
    exec ${lib.getExe pkgs.hypr-open} \
      --window-class code \
      --new-window-argument="--new-window" \
      -- \
      ${lib.getExe pkgs.vscode} \
      "$@" > /dev/null 2>&1
  '';

  # Open URLs in the chromium instance on the current workspace.
  # Otherwise, open a new instance on the current workspace.
  chromium-wrapper = pkgs.writeShellScriptBin "chromium" ''
    exec ${lib.getExe pkgs.hypr-open} \
      --window-class chromium-browser \
      --new-window-argument="--new-window" \
      -- \
      ${lib.getExe config.programs.chromium.package} \
      "$@"
  '';

in
{
  imports = [
    # ./modules/blueberry.nix
    ./modules/statebus.nix
    ./modules/xssproxy.nix
    ./modules/nushell.nix
    ./modules/swaybg.nix
    ./modules/xdg-desktop-portal.nix
    ./modules/xdg-desktop-portal-hyprland.nix
    ./modules/hyprwhspr-rs/default.nix
    ./modules/quickshell
    ./modules/opencode
  ];
  config = {
    hyprwhspr-rs = {
      enable = true;
      settings = {
        shortcuts = {
          press = null;
          hold = "SUPER+V";
        };
        audio_feedback = true;
        auto_copy_clipboard = true;
        fast_vad = {
          enabled = true;
          profile = "aggressive";
        };
        transcription = {
          provider = "groq";
          request_timeout_secs = 45;
          max_retries = 2;
          groq = {
            model = "whisper-large-v3-turbo";
            endpoint = "https://api.groq.com/openai/v1/audio/transcriptions";
            prompt = "Transcribe spoken text accurately with punctuation and capitalization. Return only the transcription.";
          };
        };
      };
      hyprland = {
        enable = false;
        holdKey = "$mod, V";
      };
    };

    home.packages = with pkgs; [
      darkman
      gnome-keyring
      grim

      # Development Tools
      nixfmt
      gdb
      # nodejs  # Use direnv for projects
      clang
      jdk
      maven
      deno
      devenv
      strace
      ltrace
      kubectl
      k9s
      postgresql
      oauth2c
      # azure-cli
      (jetbrains.idea.override { forceWayland = true; })

      # Version Control
      hub
      gh
      git-cola
      git-absorb
      git-revise
      git-worktree-shell
      agent-worktree
      agent
      agents-idle
      git-xargs
      tig
      mergiraf
      jujutsu

      # Text Processing & Search
      ripgrep
      fd
      sd
      q-text-as-data
      delta
      ast-grep

      # System Tools
      brightnessctl
      socat
      file
      qemu
      darkhttpd
      lsof
      bottom
      procs
      dua
      nix-output-monitor
      nh
      systemctl-wait

      # Network Tools
      nmap
      httpie
      insomnia
      docker-compose

      # File Management
      thunar
      xfconf
      tumbler
      xfce4-exo
      file-roller
      meld

      # Media & Graphics
      imagemagick
      vlc
      gimp3
      feh
      # ffmpeg-full
      ffmpegthumbnailer
      audacity
      inkscape
      peek

      # Desktop Environment
      pavucontrol
      lxappearance
      networkmanagerapplet
      dconf
      wl-clipboard-rs
      wl-screenrecord
      wl-screenshot
      hypr-notify

      # Security & Privacy
      bitwarden-desktop
      bitwarden-cli
      bitwarden-cli-bio
      keepassxc
      gnupg
      seahorse

      # Communication & Collaboration
      slack
      zoom-us
      signal-desktop

      # Text Editors & IDEs
      helix
      (lib.hiPrio vscode-wrapper)
      editor
      terminal
      reassign-workspace
      (lib.hiPrio chromium-wrapper)

      # Productivity
      pomodoro
      libreoffice
      speedcrunch
      chatgpt-cli
      vja
      # CLI Utilities
      entr
      xclip
      jq
      graphviz
      screen
      yq-go
      watchexec
      difftastic
      dust
      fx
      cachix
      ijq
      # nodePackages.zx
      xdg-utils
      nixpkgs-review
      tabiew
      vex-tui

      # Fonts
      liberation_ttf
      ttf_bitstream_vera

      # Misc
      coin
      patchelf
      home-manager
    ];

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.waylandFrontend = true;
    };

    programs.rofi = {
      enable = true;
      plugins = [
        pkgs.rofi-emoji
      ];
      theme =
        let
          rofi-themes-collection = pkgs.fetchFromGitHub {
            owner = "newmanls";
            repo = "rofi-themes-collection";
            rev = "ec731cef79d39fc7ae12ef2a70a2a0dd384f9730";
            hash = "sha256-96wSyOp++1nXomnl8rbX5vMzaqRhTi/N7FUq6y0ukS8=";
          };
        in
        "${rofi-themes-collection}/themes/rounded-blue-dark.rasi";
    };

    wayland.windowManager.hyprland =
      let
        # Starts Bitwarden and 1Password when the vault workspace is first opened.
        # Used as on-created-empty for the vault workspace.
        # 1Password's main window is moved to the vault by listening for
        # the windowtitlev2 IPC event — static windowrules can't distinguish
        # the main window from the auth dialog since both share initialTitle
        # "1Password" at creation time.
        slackOpen = pkgs.writeShellScript "slack-open" ''
          # Start Slack if not already running
          if ! hyprctl clients -j | ${pkgs.jq}/bin/jq -e '.[] | select(.initialClass == "Slack")' > /dev/null 2>&1; then
            slack &
            disown
          fi

          # Poll until the Slack main window appears, then move it to the slack workspace.
          for _ in $(seq 1 20); do
            address=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r '
              .[] | select(.initialClass == "Slack") | .address
            ' | head -1)
            if [[ -n "$address" ]]; then
              hyprctl dispatch movetoworkspacesilent "special:slack,address:$address"
              break
            fi
            sleep 0.5
          done
        '';

        vaultOpen = pkgs.writeShellScript "vault-open" ''
          # Start Bitwarden if not already running
          if ! hyprctl clients -j | ${pkgs.jq}/bin/jq -e '.[] | select(.class == "Bitwarden")' > /dev/null 2>&1; then
            bitwarden &
            disown
          fi

          # Start 1Password if not already running
          if ! hyprctl clients -j | ${pkgs.jq}/bin/jq -e '.[] | select(.class == "1password")' > /dev/null 2>&1; then
            1password &
            disown
          fi

          # Poll until the 1Password main window appears (title contains "— 1Password"),
          # then move it to the vault and unpin/unfloat it.
          for _ in $(seq 1 20); do
            address=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r '
              .[] | select(.class == "1password") | .address
            ' | head -1)
            if [[ -n "$address" ]]; then
                hyprctl dispatch movetoworkspacesilent "special:vault,address:$address"
                # togglefloating also unpins the window
                hyprctl dispatch togglefloating address:"$address"
              break
            fi
            sleep 0.5
          done
        '';

        toggleWorkspaceLayout = pkgs.writeShellScript "toggle-workspace-layout" ''
          set -eu

          active_workspace_json="$(${lib.getExe' pkgs.hyprland "hyprctl"} -j activeworkspace)"
          ws_id="$(printf '%s' "$active_workspace_json" | ${lib.getExe pkgs.jq} --raw-output '.id')"
          current_layout="$(printf '%s' "$active_workspace_json" | ${lib.getExe pkgs.jq} --raw-output '.tiledLayout')"

          if [ "$current_layout" = "scrolling" ]; then
            exec ${lib.getExe' pkgs.hyprland "hyprctl"} keyword workspace "$ws_id, layout:dwindle, gapsin:0, gapsout:0"
          else
            exec ${lib.getExe' pkgs.hyprland "hyprctl"} keyword workspace "$ws_id, layout:scrolling, layoutopt:direction:right, gapsin:8, gapsout:28"
          fi
        '';
      in
      {
        configType = "lua";
        enable = true;
        systemd.enable = false;
        systemd.variables = [ "--all" ];
        settings = {
          "$mod" = "SUPER";

          general = {
            gaps_in = 0;
            gaps_out = 0;
            no_focus_fallback = false;
          };

          workspace = [
            "special:vault, shadow:true, on-created-empty:${vaultOpen}, gapsin:10, gapsout:60"
            "special:slack, shadow:true, on-created-empty:${slackOpen}, gapsin:10, gapsout:60"
          ];

          scrolling = {
            direction = "right";
          };

          windowrule = [
            # IntelliJ IDEs
            "no_initial_focus on, match:class (jetbrains-.*), match:title ^win(.*)"
            "size 672 700, match:class (jetbrains-.*), match:title (), match:float 1"

            # Zoom-us
            "float on, match:class (Zoom Workplace), suppress_event maximize, pin on, dim_around off, decorate off"

            # Bitwarden on the vault workspace
            "match:class (Bitwarden), no_screen_share on, workspace special:vault silent, rounding 12"

            # All 1Password windows: float + pin by default (auth dialog, quick access, etc.)
            # The vault-open script unpins and unfloats the main window after moving it.
            "match:class (1password), no_screen_share on, rounding 12, float on, pin on"

            # Grouped/tabbed windows look better without the slide-in animation.
            "no_anim 1, match:group 1"

          ];

          env =
            let
              envkv = {
                BROWSER = "chromium";
                EDITOR = "code --wait";

                # Source: https://github.com/NixOS/nixpkgs/issues/271461#issuecomment-1934829672
                ELECTRON_OZONE_PLATFORM_HINT = "wayland";

                # Source: https://github.com/NixOS/nixpkgs/blob/45004c6f6330b1ff6f3d6c3a0ea8019f6c18a930/nixos/modules/programs/sway.nix#L47-L53
                SDL_VIDEODRIVER = "wayland";
                QT_QPA_PLATFORM = "wayland";
                QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
                _JAVA_AWT_WM_NONREPARENTING = "1";

                # Source: https://wiki.archlinux.org/title/Wayland#Clutter
                CLUTTER_BACKEND = "wayland";

                MOZ_DISABLE_RDD_SANDBOX = "1";
                EGL_PLATFORM = "wayland";

                # Make Chromium and Electron use Ozone Wayland support
                NIXOS_OZONE_WL = "1";
              };
            in
            mapAttrsToList (k: v: "${k},${v}") envkv;

          bind = [
            "$mod, T, exec, ghostty --working-directory=$HOME"
            "$mod, W, exec, chromium"
            "$mod, E, exec, thunar"
            "$mod, Q, exec, ${config.programs.rofi.finalPackage}/bin/rofi -show combi -modes combi -combi-modes run,emoji -combi-hide-mode-prefix"
            "$mod, Delete, exec, loginctl lock-session"
            "$mod, Print, exec, flameshot gui"
            "$mod SHIFT, Print, exec, wl-screenrecord"
            "$mod, C, killactive"

            # Focus movement
            "$mod, H, movefocus, l"
            "$mod, J, movefocus, u"
            "$mod, K, movefocus, d"
            "$mod, L, movefocus, r"
            "$mod, Left, movefocus, l"
            "$mod, Up, movefocus, u"
            "$mod, Down, movefocus, d"
            "$mod, Right, movefocus, r"
            "$mod, Tab, changegroupactive, f"
            "$mod SHIFT, Tab, changegroupactive, b"

            # Move window
            "$mod SHIFT, H, movewindow, l"
            "$mod SHIFT, K, movewindow, u"
            "$mod SHIFT, J, movewindow, d"
            "$mod SHIFT, L, movewindow, r"
            "$mod SHIFT, Left, movewindow, l"
            "$mod SHIFT, Up, movewindow, u"
            "$mod SHIFT, Down, movewindow, d"
            "$mod SHIFT, Right, movewindow, r"

            # Resize window
            "$mod CTRL, Left, resizeactive, -20 0"
            "$mod CTRL, Down, resizeactive, 0 20"
            "$mod CTRL, Up, resizeactive, 0 -20"
            "$mod CTRL, Right, resizeactive, 20 0"

            # Split/Fullscreen/Layout
            "$mod, G, togglegroup"
            "$mod, F, fullscreen, 1"
            "$mod SHIFT, F, togglefloating"
            "$mod, S, exec, ${toggleWorkspaceLayout}"
            "$mod, comma, layoutmsg, focus l"
            "$mod, period, layoutmsg, focus r"
            "$mod SHIFT, comma, layoutmsg, swapcol l"
            "$mod SHIFT, period, layoutmsg, swapcol r"
            "$mod, P, layoutmsg, promote"

            # Workspaces
            "$mod, 1, workspace, 1"
            "$mod, 2, workspace, 2"
            "$mod, 3, workspace, 3"
            "$mod, 4, workspace, 4"
            "$mod, 5, workspace, 5"
            "$mod, 6, workspace, 6"
            "$mod, 7, workspace, 7"
            "$mod, 8, workspace, 8"
            "$mod, 9, workspace, 9"
            "$mod, 0, workspace, 10"
            "$mod SHIFT, 1, movetoworkspace, 1"
            "$mod SHIFT, 2, movetoworkspace, 2"
            "$mod SHIFT, 3, movetoworkspace, 3"
            "$mod SHIFT, 4, movetoworkspace, 4"
            "$mod SHIFT, 5, movetoworkspace, 5"
            "$mod SHIFT, 6, movetoworkspace, 6"
            "$mod SHIFT, 7, movetoworkspace, 7"
            "$mod SHIFT, 8, movetoworkspace, 8"
            "$mod SHIFT, 9, movetoworkspace, 9"
            "$mod SHIFT, 0, movetoworkspace, 10"

            # Reassign current workspace to a number
            "$mod SHIFT CTRL, 1, exec, ${lib.getExe reassign-workspace} 1"
            "$mod SHIFT CTRL, 2, exec, ${lib.getExe reassign-workspace} 2"
            "$mod SHIFT CTRL, 3, exec, ${lib.getExe reassign-workspace} 3"
            "$mod SHIFT CTRL, 4, exec, ${lib.getExe reassign-workspace} 4"
            "$mod SHIFT CTRL, 5, exec, ${lib.getExe reassign-workspace} 5"
            "$mod SHIFT CTRL, 6, exec, ${lib.getExe reassign-workspace} 6"
            "$mod SHIFT CTRL, 7, exec, ${lib.getExe reassign-workspace} 7"
            "$mod SHIFT CTRL, 8, exec, ${lib.getExe reassign-workspace} 8"
            "$mod SHIFT CTRL, 9, exec, ${lib.getExe reassign-workspace} 9"
            "$mod SHIFT CTRL, 0, exec, ${lib.getExe reassign-workspace} 10"

            # Special workspace (vault: Bitwarden + 1Password)
            "$mod, grave, togglespecialworkspace, vault"
            "$mod SHIFT, grave, movetoworkspace, special:vault"

            # Special workspace (Slack)
            "$mod, Tab, togglespecialworkspace, slack"

            # Move workspace to monitor
            "CTRL ALT $mod SHIFT, Left, movecurrentworkspacetomonitor, l"
            "CTRL ALT $mod SHIFT, Right, movecurrentworkspacetomonitor, r"

            # Restart Hyprland
            "$mod SHIFT, R, exec, hyprctl reload"

            # Media keys
            " , XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
            " , XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
            " , XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            " , XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play"
            " , XF86AudioPause, exec, ${pkgs.playerctl}/bin/playerctl pause"
            " , XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next"
            " , XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous"

            # Brightness
            " , XF86MonBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%+"
            " , XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%-"
          ];

          bindm = [
            "$mod, mouse:272, movewindow" # Drag window with SUPER + Left Mouse Button
            "$mod, mouse:273, resizewindow" # Resize window with SUPER + Right Mouse Button
          ];

          bindl = [
            "$mod, switch:[Lid Switch], exec, hyprlock"
          ];

          bezier = [
            "subtle, 0.20, 0.90, 0.25, 1.00"
          ];

          # Keep motion subtle, but restore enough movement to make scrolling
          # layout changes easier to track visually.
          animation = [
            "global, 1, 3, default"
            "fade, 0"
            "windows, 1, 2, subtle, slide"
            "workspaces, 0"
            "border, 0"
            "layers, 0"
          ];

          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            background_color = "rgb(${backgroundColor})";
          };

        };
      };

    programs.hyprlock = {
      enable = true;
      settings = {
        background = {
          color = "rgba(${backgroundColor})";
        };
        image = {
          path = "${wallpaperPng}";
          size = 535;
          rounding = 0;
          border_size = 0;
        };
        input-field = {
          size = "500, 64";
          position = "0, -300";
          font_size = 24;
          font_color = "rgba(255, 255, 255, 0.8)";
          inner_color = "rgba(0, 0, 0, 0)";
          outer_color = "rgba(255, 255, 255, 0.1)";
          outline_thickness = 1;
        };
        auth.fingerprint.enabled = true;
        animations.enabled = false;
      };
    };

    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
          on_unlock_cmd = "${lib.getExe pkgs.session-time} --reset";
        };

        listener = {
          timeout = 150;
          on-timeout = "brightnessctl -s set 10";
          on-resume = "brightnessctl -r";
        };
      };
    };
    # swaync replaced by quickshell notification center
    services.swaync.enable = false;

    programs.swaybg = {
      enable = true;
      outputs."*" = {
        mode = "center";
        color = "#${backgroundColor}";
        image = "${wallpaperPng}";
      };
    };

    # Waybar replaced by quickshell bar (see home/modules/quickshell/)
    programs.waybar.enable = false;

    services.xdg-desktop-portal = {
      enable = true;
      verbose = true;
      portals = with pkgs; [
        darkman
        xdg-desktop-portal-gtk
        gnome-keyring
      ];
    };

    services.xdg-desktop-portal-hyprland = {
      enable = true;
      settings = {
        # Skip the interactive screencopy picker and pick the current monitor non-interactively.
        screencopy.custom_picker_binary =
          let
            screencopy-picker = pkgs.writeShellApplication {
              name = "screencopy-picker";
              runtimeInputs = [
                config.wayland.windowManager.hyprland.finalPackage
                pkgs.jq
              ];
              text = ''
                echo "[SELECTION]/screen:$(hyprctl activeworkspace -j | jq --raw-output .monitor)"
              '';
            };
          in
          "${screencopy-picker}/bin/screencopy-picker";
      };
    };

    dconf = {
      enable = true;
      settings = {
        "org/gnome/desktop/sound" = {
          event-sounds = false;
          input-feedback-sounds = false;
        };
      };
    };

    programs.chromium.enable = true;

    programs.lazygit = {
      enable = true;
      settings = {
        git.overrideGpg = true;
        customCommands = [
          {
            key = "N";
            context = "global";
            command = "git fetch upstream HEAD && git checkout FETCH_HEAD";
          }
          {
            key = "U";
            context = "global";
            command = "git pull upstream HEAD";
          }
        ];
        os.copyToClipboardCmd =
          let
            copyToClipboard = pkgs.writeShellScriptBin "copyToClipboard" ''
              if [[ "$TERM" =~ ^(screen|tmux) ]]; then
                printf "\033Ptmux;\033\033]52;c;$(printf "$@" | base64 -w 0)\a\033\\" > /dev/tty
              else
                printf "\033]52;c;$(printf "$@" | base64 -w 0)\a" > /dev/tty
              fi
            '';
          in
          ''
            ${copyToClipboard}/bin/copyToClipboard {{text}}
          '';
        os.readFromClipboardCmd = ''
          ${pkgs.wl-clipboard-rs}/bin/wl-paste
        '';
      };
    };

    fonts.fontconfig.enable = true;
    manual.manpages.enable = false;
    # Fish enables man cache generation by default, which triggers noisy mandb warnings.
    programs.man.generateCaches = false;
    gtk = {
      enable = true;
      font = {
        name = "Noto Sans 10";
        package = pkgs.noto-fonts;
      };
      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      gtk4.theme = config.gtk.theme;
      gtk2.extraConfig = ''
        gtk-error-bell = 0
      '';

      gtk3.extraConfig = {
        gtk-error-bell = 0;
      };
    };
    programs.ssh = {
      enable = true;
      # To prepare for default config deprecation.
      enableDefaultConfig = false;
      matchBlocks = {
        "*".serverAliveInterval = 180;
        "beheer1.ioservice.net beheer1.stpst.nl beheer2.ioservice.net beheer2.stpst.nl" = {
          user = "bob.vanderlinden";
          forwardAgent = false;
          identityFile = "~/.ssh/nedap_rsa";
        };

        "nl12* nl14* nl22* nl24* vm* nvs* nas* *.healthcare.nedap.local *.consul" = {
          user = "bob.vanderlinden";
          forwardAgent = false;
          identityFile = "~/.ssh/nedap_rsa";
          extraOptions = {
            VerifyHostKeyDNS = "no";
            ProxyJump = "beheer1.ioservice.net";
          };
        };

        "127.0.0.1" = {
          user = "bob.vanderlinden";
          forwardAgent = false;
          identityFile = "~/.ssh/nedap_rsa";
          extraOptions.VerifyHostKeyDNS = "no";
        };

        "github.com gist.github.com" = {
          user = "git";
          identityFile = "~/.ssh/github_ed25519";
        };
      };
    };
    programs.fzf.enable = true;
    programs.bat.enable = true;
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting

        # Capture Hyprland window address for notifications (only in Ghostty)
        if test "$TERM_PROGRAM" = ghostty
          set -gx HYPR_WINDOW_ADDRESS (hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.address | ltrimstr("0x")')
        end
      '';
    };

    programs.starship = {
      enable = true;
      settings = {
        character = {
          success_symbol = "[\\$](bold blue)";
          error_symbol = "[\\$](bold red)";
        };
      };
    };

    programs.atuin = {
      enable = true;
      flags = [ "--disable-up-arrow" ];
      settings = {
        auto_sync = false;
        update_check = false;
        style = "compact";
        ui.columns = [
          "duration"
          "time"
          "directory"
          "command"
        ];
      };
    };

    programs.zoxide.enable = true;

    qt = {
      enable = true;
      platformTheme.name = "adwaita";
      style = {
        name = "adwaita";
        package = pkgs.adwaita-qt;
      };
    };

    services.gpg-agent.enable = true;

    services.blueman-applet.enable = true;
    services.statebus.enable = true;
    services.mpris-proxy.enable = true;
    services.flameshot = {
      enable = true;
      # package = pkgs.flameshot.overrideAttrs (old: {
      #   src = pkgs.fetchFromGitHub {
      #     owner = "flameshot-org";
      #     repo = "flameshot";
      #     rev = "f7a049ee78531b7dfa36ead4945ce9c721d90bfe";
      #     hash = "sha256-teAvx50AvMjKcW44pdWxThTuJvUBeK4YI5fUmBQD9lI=";
      #   };
      #   patches = [ ];
      #   postFixup = ''
      #     wrapProgram $out/bin/flameshot \
      #       --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.grim ]} \
      #       ''${qtWrapperArgs[@]}
      #   '';
      # });
      settings = {
        General = {
          showDesktopNotification = false;
          showStartupLaunchMessage = false;
          # useGrimAdapter = true;
          # disabledGrimWarning = true;
        };
      };
    };

    services.darkman = {
      enable = true;
      settings = {
        lat = 51.974882858758626;
        lng = 5.9115896491034565;
      };
    };

    services.gammastep = {
      enable = true;
      latitude = 51.974882858758626;
      longitude = 5.9115896491034565;
      temperature.day = 5500;
      temperature.night = 3700;
      tray = true;
    };

    services.xsettingsd = {
      enable = true;
      settings = {
        "Net/ThemeName" = "Adwaita-dark";
        "Xft/Antialias" = true;
        "Xft/Hinting" = true;
        "Xft/RGBA" = "rgb";
      };
    };

    programs.ghostty = {
      enable = true;
      settings = {
        window-decoration = false;
        resize-overlay = "never";
        theme = "dark:Adwaita Dark,light:Adwaita";
        keybind = [
          "shift+enter=text:\\n"
        ];
        app-notifications = [
          "no-clipboard-copy"
        ];

      };
    };

    services.xssproxy.enable = false;
    services.lxqt-policykit-agent.enable = false;
    services.polkit-gnome.enable = false; # replaced by PolkitAgent.qml in quickshell
    services.hyprpolkitagent.enable = false;

    xdg.enable = true;
    # news.display = "silent";

    home.pointerCursor = {
      x11.enable = true;
      gtk.enable = true;
      hyprcursor.enable = true;
      name = "Vanilla-DMZ";
      package = pkgs.vanilla-dmz;
      size = 128;
    };

    home.shellAliases = {
      g = "git";
      bw = "bwbio";
    };

    programs.git = {
      enable = true;
      package = pkgs.gitFull;

      # Use specific configuration for work projects.
      includes =
        let
          nedap-config = {
            user.name = "Bob van der Linden";
            user.email = "bob.vanderlinden@nedap.com";
          };
        in
        [
          {
            condition = "gitdir:~/projects/nedap/**";
            contents = nedap-config;
          }
          {
            condition = "gitdir:~/projects/meditools/**";
            contents = nedap-config;
          }
        ];

      signing = {
        key = "~/.ssh/github_ed25519.pub";
        signByDefault = true;
        format = "ssh";
      };

      ignores = [
        "vendor"
        "workspace.code-workspace"

        # Always ignore devenv.sh temporary files.
        ".devenv"
        ".devenv.flake.nix"
      ];
      settings = {
        user = {
          name = "Bob van der Linden";
          email = "bobvanderlinden@gmail.com";
        };

        alias = {
          unstage = "reset HEAD --";
          sw = "switch";
          co = "checkout";
          c = "commit";
          b = "branch";
          p = "push";
          pf = "push --force-with-lease --force";
          d = "diff";
          a = "add";
          s = "status";
          f = "fetch";
          t = "tag";
          bl = "blame -w -C -C -C";
          l = "log --graph --pretty='%Cred%h%Creset - %C(bold blue)<%an>%Creset %s%C(yellow)%d%Creset %Cgreen(%cr)' --abbrev-commit --date=relative";
          fixup = "commit --fixup";
          pr-init = ''
            !git fetch upstream HEAD && git checkout upstream/HEAD -b $1
          '';
          pr-diff = "diff upstream/HEAD...HEAD";
          pr-log = "l upstream/HEAD..";
          pr-edit = "rebase --interactive --autosquash --rerere-autoupdate --rebase-merges --fork-point upstream/HEAD";
          pr-clean = "rebase --autosquash --rerere-autoupdate --empty drop --no-keep-empty --rebase-merges --fork-point upstream/HEAD";
          pr-update = "pull --rebase=merges upstream HEAD";
          pr-bisect = "!git bisect start && git bisect bad HEAD; git bisect good $(git merge-base --fork-point upstream/HEAD HEAD)";
        };

        init.defaultBranch = "main";

        column.ui = "auto";

        core.editor = "code --wait";

        # Show diff in commit message editor.
        commit.verbose = true;

        # Use more descriptive diff prefixes than a/ and b/.
        # See https://git-scm.com/docs/diff-config#Documentation/diff-config.txt-diffmnemonicPrefix
        diff.mnemonicPrefix = true;

        diff.algorithm = "patience";

        # Show moved lines in diff.
        diff.colorMoved = "zebra";

        diff.renames = true;

        push.default = "current";
        push.autoSetupRemote = true;
        pull.rebase = true;

        rebase.autoSquash = true;
        rebase.autoStash = true;
        rebase.rebaseMerges = true;
        rebase.updateRefs = true;

        # Record and replay conflict resolutions.
        rerere.enabled = true;
        rerere.autoupdate = true;

        # Sort last committed branches to top.
        branch.sort = "-committerdate";

        # Sort highest version to top.
        tag.sort = "-v:refname";

        credential.helper = "${config.programs.git.package}/bin/git-credential-libsecret";

        # Avoid hint: use --reapply-cherry-picks to include skipped commits
        advice.skippedCherryPicks = false;

        # Avoid hint: use git switch -c <new-branch-name> to retain commits
        advice.detachedHead = false;

        help.autocorrect = "prompt";

        url."git@github.com:".insteadOf = [
          # Normalize GitHub URLs to SSH to avoid authentication issues with HTTPS.
          "https://github.com/"

          # Allows typing `git clone github:owner/repo`.
          "github:"
        ];

        # Source: https://github.com/rust-lang/cargo/issues/3381#issuecomment-1193730972
        # avoid issues where the cargo-edit tool tries to clone from a repo you do not have WRITE access to.
        # we already use SSH for every github repo, and so this puts the clone back to using HTTPS.
        url."https://github.com/rust-lang/crates.io-index".insteadOf =
          "https://github.com/rust-lang/crates.io-index";

        # avoid issues where the `cargo audit` command tries to clone from a repo you do not have WRITE access to.
        # we already use SSH for every github repo, and so this puts the clone back to using HTTPS.
        url."https://github.com/RustSec/advisory-db".insteadOf = "https://github.com/RustSec/advisory-db";

        # Let git absorb look at 100 parents.
        absorb.maxStack = 100;
      };
    };

    programs.difftastic = {
      enable = true;
      git.enable = true;
    };

    programs.mergiraf = {
      enable = true;
      enableJujutsuIntegration = true;
      enableGitIntegration = true;
    };
    programs.gh = {
      enable = true;
      settings = {
        # See https://github.com/nix-community/home-manager/issues/4744
        version = "1";
        editor = "code --wait";
      };
    };
    programs.gh-dash.enable = true;
    programs.jq.enable = true;
    programs.neovim = {
      enable = true;
      withRuby = true;
      withPython3 = true;
    };
    programs.nix-index.enable = true;

    # Source: https://discourse.nixos.org/t/atril-is-blurry-engrampa-is-not-sway-scale-2/2865/2
    xresources.properties."Xft.dpi" = "96";

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;

      # Store .envrc files outside of project directories.
      # Source: https://github.com/nix-community/nix-direnv#storing-direnv-outside-the-project-directory
      stdlib = builtins.readFile ./direnvrc;
    };
    programs.htop.enable = true;

    services.activitywatch = {
      enable = true;
      watchers = {
        aw-watcher-window-hyprland = {
          package = pkgs.aw-watcher-window-hyprland;
        };
      };
    };

    # Home Manager normally expects the session launcher to start
    # hm-graphical-session.target, which in turn activates
    # graphical-session.target and tray.target. With uwsm launching Hyprland,
    # bridge that behavior onto the uwsm per-session target instead.
    systemd.user.targets.hm-graphical-session = {
      Unit = {
        Description = "Home Manager graphical session";
        Requires = [ "graphical-session-pre.target" ];
        After = [ hyprlandSessionTarget ];
        BindsTo = [
          hyprlandSessionTarget
          "graphical-session.target"
          "tray.target"
        ];
      };
      Install.WantedBy = [ hyprlandSessionTarget ];
    };

    # The activitywatch watcher module does not expose a way to set service
    # environment variables, so we override the unit to pass through the
    # Hyprland IPC socket identifier that hyprctl needs to connect.
    # With uwsm, bind it directly to the compositor session target so it picks
    # up a fresh instance signature on Hyprland restarts.
    # xsettingsd also needs the session environment imported by uwsm before it
    # starts, otherwise it races Xwayland and fails to connect to DISPLAY.
    systemd.user.services.xsettingsd = {
      Unit = {
        BindsTo = [ hyprlandSessionTarget ];
        After = [ hyprlandSessionTarget ];
        PartOf = [ hyprlandSessionTarget ];
      };
      Install.WantedBy = lib.mkForce [ hyprlandSessionTarget ];
    };

    systemd.user.services.activitywatch-watcher-aw-watcher-window-hyprland = {
      Unit = {
        BindsTo = [ hyprlandSessionTarget ];
        After = [ hyprlandSessionTarget ];
      };
      Install.WantedBy = [ hyprlandSessionTarget ];
      Service.PassEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
    };

    home.stateVersion = "21.03";
  };
}
