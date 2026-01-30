{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mapAttrsToList;

  backgroundColor = "1a1b26";
  wallpaperSvg = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/4ad062cee62116f6055e2876e9638e7bb399d219/logo/nix-snowflake-colours.svg";
    hash = "sha256-43taHBHoFJbp1GrwSQiVGtprq6pBbWcKquSTTM6RLrI=";
  };
  wallpaperPng = pkgs.runCommand "nix-snowflake.png" { } ''
    ${pkgs.resvg}/bin/resvg ${wallpaperSvg} $out
  '';

  cursor-wrapper = pkgs.writeShellScriptBin "cursor" ''
    # Disable any custom node options that some projects might have.
    # These conflict with node inside cursor/vscode.
    export NODE_OPTIONS=""

    # Open files in the cursor instance on the current workspace.
    # Otherwise, open a new instance on the current workspace.
    exec ${lib.getExe pkgs.hypr-open} \
      --window-class cursor \
      --new-window-argument="--new-window" \
      -- \
      ${lib.getExe pkgs.code-cursor} \
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
    ./modules/blueberry.nix
    ./modules/xssproxy.nix
    ./modules/nushell.nix
    ./modules/swaybg.nix
    ./modules/xdg-desktop-portal.nix
    ./modules/xdg-desktop-portal-hyprland.nix
  ];
  config = {
    home.packages = with pkgs; [
      darkman
      gnome-keyring
      grim

      # Development Tools
      nixfmt
      gdb
      nodejs
      clang
      jdk
      maven
      deno
      devenv
      watchman
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
      git-xargs
      tig
      mergiraf

      # Text Processing & Search
      ripgrep
      fd
      sd
      q-text-as-data
      delta
      ast-grep

      # System Tools
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
      ffmpeg-full
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

      # Security & Privacy
      bitwarden-desktop
      bitwarden-cli
      keepassxc
      gnupg
      seahorse

      # Communication & Collaboration
      slack
      zoom-us
      signal-desktop

      # Text Editors & IDEs
      helix
      code-cursor
      # (lib.hiPrio cursor-wrapper)
      (lib.hiPrio chromium-wrapper)

      # Productivity
      pomodoro
      libreoffice
      speedcrunch
      chatgpt-cli

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

      # Fonts
      liberation_ttf
      ttf_bitstream_vera

      # Misc
      coin
      patchelf
      home-manager
      claude-code
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

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.variables = [ "--all" ];
      settings = {
        "$mod" = "SUPER";

        general = {
          gaps_in = 0;
          gaps_out = 0;
        };

        windowrulev2 = [
          # IntelliJ IDEs
          "noinitialfocus,class:(jetbrains-.*),title:^win(.*)"
          "size 672 700,class:(jetbrains-.*),title:(),floating:1"

          # Zoom-us
          "float,class:(Zoom Workplace)"
          # "move onscreen 50% 100%,class:(Zoom Workplace),title:(as_toolbar)"
        ];

        #
        env =
          let
            envkv = {
              BROWSER = "chromium";
              EDITOR = "cursor --wait";

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

        bind =
          let
            swayosd_client = "${config.services.swayosd.package}/bin/swayosd-client";
          in
          [
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

            # Move workspace to monitor
            "CTRL ALT $mod SHIFT, Left, movecurrentworkspacetomonitor, l"
            "CTRL ALT $mod SHIFT, Right, movecurrentworkspacetomonitor, r"

            # Restart Hyprland
            "$mod SHIFT, R, exec, hyprctl reload"

            # Media keys
            " , XF86AudioRaiseVolume, exec, ${swayosd_client} --output-volume raise"
            " , XF86AudioLowerVolume, exec, ${swayosd_client} --output-volume lower"
            " , XF86AudioMute, exec, ${swayosd_client} --output-volume mute-toggle"
            " , XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play"
            " , XF86AudioPause, exec, ${pkgs.playerctl}/bin/playerctl pause"
            " , XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next"
            " , XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous"

            # Brightness
            " , XF86MonBrightnessUp, exec, ${swayosd_client} --brightness raise"
            " , XF86MonBrightnessDown, exec, ${swayosd_client} --brightness lower"

            # Voxtype voice-to-text (push-to-talk: press to record)
            "$mod, V, exec, ${config.programs.voxtype.package}/bin/voxtype record start"
          ];

        bindr = [
          # Voxtype voice-to-text (push-to-talk: release to stop and transcribe)
          "$mod, V, exec, ${config.programs.voxtype.package}/bin/voxtype record stop"
        ];

        bindm = [
          "$mod, mouse:272, movewindow" # Drag window with SUPER + Left Mouse Button
          "$mod, mouse:273, resizewindow" # Resize window with SUPER + Right Mouse Button
        ];

        bindl = [
          "$mod, switch:[Lid Switch], exec, hyprlock"
        ];

        # Disable all Hyprland animations (see https://wiki.hyprland.org/Configuring/Animations/)
        animation = [
          "global, 0"
          "fade, 0"
          "windows, 0"
          "workspaces, 0"
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
    services.swayosd.enable = true;
    services.swaync = {
      enable = true;
      settings = {
        positionX = "right";
        positionY = "bottom";
        layer = "overlay";
      };
    };

    programs.swaybg = {
      enable = true;
      outputs."*" = {
        mode = "center";
        color = "#${backgroundColor}";
        image = "${wallpaperPng}";
      };
    };

    systemd.user.services.waybar.Unit.Requisite = config.programs.waybar.systemd.target;
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      style = ''
        @import "${config.programs.waybar.package}/etc/xdg/waybar/style.css";

        #workspaces button.active {
          background-color: #64727D;
          box-shadow: inset 0 -3px #ffffff;
        }

        #privacy-item.screenshare {
            background-color: #cf5700;
        }

        #privacy-item.audio-in {
            background-color: #cf5700;
        }

        #privacy-item.audio-out {
            background-color: #cf5700;
        }

        #custom-voxtype {
          background-color: #999999;
        }

        #custom-docker {
          padding: 0 10px;
          background-color: #1D63ED;
        }

        #custom-session_time {
          padding: 0 10px;
          background-color:#008261;
        }
      '';
      settings = {
        mainBar = {
          position = "bottom";
          modules-left = [
            "hyprland/workspaces"
          ];
          modules-center = [ ];
          modules-right = [
            "systemd_failed_units"
            "privacy"
            "custom/docker"
            "custom/session_time"
            "custom/voxtype"
            "network"
            "battery"
            "wireplumber"
            # "cpu"
            "clock"
            "tray"
          ];
          "hyprland/workspaces" = {
            format = "{icon}";
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
          };
          "hyprland/window" = {
            separate-outputs = true;
          };
          systemd_failed_units = { };
          privacy = {
            icon-size = 12;
          };
          "custom/docker" = {
            format = "{}  ";
            interval = 10;
            tooltip-format = "{} containers running";
            exec =
              let
                docker-count = pkgs.writeShellApplication {
                  name = "docker-count";
                  text = ''
                    docker ps --format json | jq --slurp 'length'
                  '';
                  runtimeInputs = [
                    pkgs.docker
                    pkgs.jq
                  ];
                };
              in
              "${docker-count}/bin/docker-count";
          };
          "custom/session_time" = {
            format = "{} 🔒";
            interval = 60;
            exec = "${lib.getExe pkgs.session-time}";
          };
          "custom/voxtype" = {
            exec = "${config.programs.voxtype.package}/bin/voxtype status --follow --format json";
            return-type = "json";
            format = "{}";
            tooltip = true;
          };
          network = {
            format = "";
            format-wired = "";
            format-linked = "";
            format-wifi = "{essid}  ";
            format-disconnected = "";
            tooltip-format = "{ifname}\n{ipaddr}\n{essid} ({signalStrength}%)";
          };
          cpu = {
            interval = 10;
            format = "{}% ";
            max-length = 10;
          };
          battery = {
            format = "{capacity}% {icon}";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
            format-charging = "<span font='Font Awesome 5 Free'></span>  {capacity}% - {time} <span font='Font Awesome 5 Free 11'>{icon}</span>";
            format-full = "<span font='Font Awesome 5 Free'></span>  Charged <span font='Font Awesome 5 Free 11'>{icon}</span>";
          };
          wireplumber = {
          };
          clock = {
            format = "{:%a, %d. %b  %H:%M}";
          };
        };
      };
    };

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

    services.network-manager-applet.enable = true;
    services.blueberry.enable = true;
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
    services.polkit-gnome.enable = true;
    services.hyprpolkitagent.enable = false;

    services.pasystray.enable = true;
    programs.voxtype = {
      enable = true;
      package = inputs.voxtype.packages.${pkgs.system}.default;
      service.enable = true;
      model.name = "base.en";
      settings = {
        state_file = "auto";
        hotkey.enabled = false; # Using Hyprland keybindings instead
        audio = {
          device = "default";
          sample_rate = 16000;
          max_duration_secs = 60;
        };
        whisper.language = "en";
        output = {
          mode = "type";
          notification.on_transcription = true;
        };
        status.icon_theme = "emoji";
      };
    };

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
          pr-clean = "rebase --autosquash --rerere-autoupdate --empty drop --no-keep-empty --fork-point upstream/HEAD";
          pr-update = "pull --rebase=merges upstream HEAD";
          pr-bisect = "!git bisect start && git bisect bad HEAD; git bisect good $(git merge-base --fork-point upstream/HEAD HEAD)";
        };

        init.defaultBranch = "main";

        column.ui = "auto";

        core.editor = "cursor --wait";

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

    programs.mergiraf.enable = true;
    programs.gh = {
      enable = true;
      settings = {
        # See https://github.com/nix-community/home-manager/issues/4744
        version = "1";
        editor = "cursor --wait";
      };
    };
    programs.jq.enable = true;
    programs.neovim.enable = true;
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
        aw-watcher-afk = {
          package = pkgs.activitywatch;
        };
        aw-watcher-window-hyprland = {
          package = pkgs.aw-watcher-window-hyprland;
        };
      };
    };

    home.stateVersion = "21.03";
  };
}
