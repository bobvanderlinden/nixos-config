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
  unisic = inputs.unisic.packages.${pkgs.stdenv.hostPlatform.system}.unisic;
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
    if [[ $# -eq 0 ]]; then
      ghostty --working-directory="$PWD" > /dev/null 2>&1 &
    else
      command="shell:exec"
      for argument in "$@"; do
        printf -v quoted_argument ' %q' "$argument"
        command+="$quoted_argument"
      done
      ghostty --working-directory="$PWD" --command="$command" > /dev/null 2>&1 &
    fi
    disown
  '';

  reassign-workspace = pkgs.writeShellScriptBin "reassign-workspace" ''
    target=$1
    current=$(${lib.getExe' pkgs.hyprland "hyprctl"} activeworkspace -j | ${lib.getExe pkgs.jq} --raw-output '.id')
    ${lib.getExe' pkgs.hyprland "hyprctl"} clients -j \
      | ${lib.getExe pkgs.jq} --raw-output --argjson current "$current" \
          '.[] | select(.workspace.id == $current) | .address' \
      | while read -r address; do
          ${lib.getExe' pkgs.hyprland "hyprctl"} dispatch "hl.dsp.window.move({ workspace = \"$target\", window = \"address:$address\", silent = true })"
        done
    ${lib.getExe' pkgs.hyprland "hyprctl"} dispatch "hl.dsp.focus({ workspace = \"$target\" })"
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
    # Slack/Electron can launch the browser with CHROME_DESKTOP=slack.
    # Chromium uses CHROME_DESKTOP as its Wayland app_id, which makes
    # Hyprland see Chromium windows as Slack windows and apply Slack rules.
    export CHROME_DESKTOP=chromium-browser

    exec ${lib.getExe pkgs.hypr-open} \
      --window-class chromium-browser \
      --window-title-suffix=" - Chromium" \
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
    ./modules/hypr
    ./modules/hyprwhspr-rs/default.nix
    ./modules/quickshell
    ./modules/pi
  ];
  config = {
    hyprwhspr-rs = {
      enable = true;
      settings = {
        shortcuts = {
          press = null;
          hold = null;
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
            model = "whisper-large-v3";
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

      # Development Tools
      nixfmt
      gdb
      nodejs
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
      datadog-pup
      # azure-cli

      # Version Control
      hub
      gh
      gh-batch-merge
      git-cola
      git-absorb
      git-revise
      hypr-exec
      worktree
      agent-worktree
      new-agent
      agent
      agents-idle
      git-xargs
      git-pr-clean
      tig
      mergiraf
      jujutsu
      hunk
      tuicr

      # Text Processing & Search
      ripgrep
      fd
      sd
      q-text-as-data
      delta
      ast-grep
      xan

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
      adhoc

      # Network Tools
      nmap
      httpie
      xh
      nix-search-cli
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

      # Desktop Environment
      pavucontrol
      lxappearance
      networkmanagerapplet
      dconf
      wl-clipboard-rs
      unisic
      hypr-notify

      # Security & Privacy
      bitwarden-desktop
      bitwarden-cli
      # bitwarden-cli-bio
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

    systemd.user.services.hypridle-suspend = {
      Unit.Description = "Suspend after hypridle timeout once inhibitors clear";
      Service = {
        Type = "exec";
        ExecStart = pkgs.writeShellScript "hypridle-suspend" ''
          ${lib.getExe' pkgs.systemctl-wait "systemctl-wait"} suspend-then-hibernate --interval 10 \
            || ${lib.getExe' pkgs.systemctl-wait "systemctl-wait"} suspend --interval 10
        '';
      };
    };

    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
          on_unlock_cmd = "${lib.getExe pkgs.session-time} --reset";
        };

        listener = [
          {
            timeout = 150;
            on-timeout = "brightnessctl -s set 10";
            on-resume = "brightnessctl -r";
          }
          {
            timeout = 30 * 60;
            on-timeout = "systemctl --user start hypridle-suspend.service";
            on-resume = "systemctl --user stop hypridle-suspend.service";
          }
        ];
      };
    };
    # swaync replaced by quickshell notification center
    services.swaync.enable = false;

    services.cliphist = {
      enable = true;
      systemdTargets = [ "hyprland-session.target" ];
    };

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
      target = "hyprland-session.target";
      verbose = true;
      portals = with pkgs; [
        darkman
        xdg-desktop-portal-gtk
        gnome-keyring
      ];
    };

    services.xdg-desktop-portal-hyprland = {
      enable = true;
      target = "hyprland-session.target";
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
        "org/gnome/desktop/interface".icon-theme = "Papirus-Dark";
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
          {
            key = "T";
            context = "global";
            command = "${lib.getExe pkgs.tuicr} -w";
            description = "Review working tree with tuicr";
            output = "terminal";
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
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
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
      settings."*" = { };
      extraConfig = ''
        Host 127.0.0.1
          ForwardAgent no
          User bob.vanderlinden
          IdentityFile ~/.ssh/nedap_rsa
          VerifyHostKeyDNS no

        Host beheer1.ioservice.net beheer1.stpst.nl beheer2.ioservice.net beheer2.stpst.nl
          ForwardAgent no
          User bob.vanderlinden
          IdentityFile ~/.ssh/nedap_rsa

        Host github.com gist.github.com
          User git
          IdentityFile ~/.ssh/github_ed25519

        Host nl12* nl14* nl22* nl24* vm* nvs* nas* *.healthcare.nedap.local *.consul
          ForwardAgent no
          User bob.vanderlinden
          IdentityFile ~/.ssh/nedap_rsa
          ProxyJump beheer1.ioservice.net
          VerifyHostKeyDNS no

        Host *
          ServerAliveInterval 180
      '';
    };
    programs.fzf = {
      enable = true;
      # Atuin owns Ctrl-R for history search; yield fzf's Ctrl-R binding to it.
      # fzf keeps Ctrl-T (files) and Alt-C (directories).
      historyWidget.command = "";
    };
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

    services.statebus.enable = true;
    services.mpris-proxy.enable = true;
    # The upstream package bundles Tesseract language data (English, Polish,
    # and script detection) and configures TESSDATA_PREFIX for OCR.
    systemd.user.services.unisic = {
      Unit = {
        Description = "Unisic screenshot and recording service";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${lib.getExe unisic} --tray-only";
        Restart = "on-failure";
        Slice = "session.slice";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
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
        "Net/IconThemeName" = "Papirus-Dark";
        "Xft/Antialias" = true;
        "Xft/Hinting" = true;
        "Xft/RGBA" = "rgb";
      };
    };
    systemd.user.services.xsettingsd = {
      Unit = {
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Install.WantedBy = lib.mkForce [ "hyprland-session.target" ];
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
      enable = true;
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
      hooks.post-checkout = ./git-hooks/post-checkout;

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
        ".pi-subagents"
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
      extensions = [
        pkgs.gh-stack
      ];
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
      enable = false;
      watchers = {
        aw-watcher-window-hyprland = {
          package = pkgs.aw-watcher-window-hyprland;
        };
      };
    };

    home.stateVersion = "21.03";
  };
}
