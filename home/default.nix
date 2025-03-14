{ pkgs, config, ... }:
let
  cursor-alias = pkgs.writeShellScriptBin "code" ''
    exec cursor "$@"
  '';
  cursor-wrapper = pkgs.writeShellScriptBin "cursor" ''
    exec ${pkgs.sway-open}/bin/sway-open \
      --app_id code-url-handler \
      --new-window-argument="--new-window" \
      -- \
      ${pkgs.code-cursor}/bin/cursor \
      "$@" > /dev/null 2>&1
  '';
  chromium-wrapper = pkgs.writeShellScriptBin "chromium" ''
    exec ${pkgs.sway-open}/bin/sway-open \
      --app_id chromium-browser \
      --new-window-argument="--new-window" \
      -- \
      ${config.programs.chromium.package}/bin/chromium \
      "$@"
  '';
in
{
  imports = [
    ./modules/blueberry.nix
    ./modules/lxqt-policykit-agent.nix
    ./modules/xssproxy.nix
    ./modules/polkit-gnome.nix
    ./modules/nushell.nix
    ./modules/mergiraf.nix
    ./modules/hyprpolkitagent.nix
  ];
  config = {
    home.packages = with pkgs; [
      # Development Tools
      nixfmt-rfc-style
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
      pgcli

      # Version Control
      hub
      gh
      git-cola
      git-absorb
      git-revise
      git-worktree-shell
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

      # Network Tools
      nmap
      httpie
      insomnia
      docker-compose

      # File Management
      xfce.thunar
      xfce.xfconf
      xfce.tumbler
      xfce.exo
      file-roller
      meld

      # Media & Graphics
      imagemagick
      vlc
      gimp
      feh
      ffmpeg-full
      ffmpegthumbnailer
      audacity
      inkscape
      peek

      # Desktop Environment
      pavucontrol
      volumeicon
      lxappearance
      i3status
      networkmanagerapplet
      dconf

      # Security & Privacy
      bitwarden-desktop
      bitwarden-cli
      keepassxc
      gnupg

      # Communication & Collaboration
      slack
      zoom-us
      thunderbird

      # Text Editors & IDEs
      helix
      (lib.hiPrio cursor-wrapper)
      (lib.hiPrio chromium-wrapper)
      cursor-alias

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
      du-dust
      fx
      cachix
      ijq
      zoxide
      nodePackages.zx
      xdg-utils
      nixpkgs-review
      tabiew

      # Fonts
      liberation_ttf
      ttf_bitstream_vera

      # Misc
      coin
      mono
      patchelf
      tiled
      home-manager
      xsel
      wl-clipboard-rs
    ];

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
        os.copyToClipboardCmd = ''
          ${pkgs.wl-clipboard-rs}/bin/wl-copy '{{text}}'
        '';
        os.readFromClipboardCmd = ''
          ${pkgs.wl-clipboard-rs}/bin/wl-paste
        '';
      };
    };

    programs.terminator = {
      enable = true;
      config = {
        global_config = {
          inactive_color_offset = "1.0";
        };
        keybindings = {
          go_next = "";
          new_window = "<Primary><Shift>n";
        };
        profiles.default = {
          background_color = "#002b36";
          cursor_color = "#aaaaaa";
          font = "SauceCodePro Nerd Font 11";
          use_system_font = false;
          foreground_color = "#839496";
          show_titlebar = false;
          scrollback_lines = 10000;
          palette = "#073642:#dc322f:#859900:#b58900:#268bd2:#d33682:#2aa198:#eee8d5:#002b36:#cb4b16:#586e75:#657b83:#839496:#6c71c4:#93a1a1:#fdf6e3";
        };
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
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };
    programs.ssh = {
      enable = true;
      forwardAgent = false;
      serverAliveInterval = 180;
      matchBlocks = {
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

    programs.nushell = {
      enable = true;
      settingss.show_banner = false;
      extraConfig = ''
        source ${
          pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/nushell/nu_scripts/e3b02b38eeece7c4ab8c20198cd36c6b12d5c3e4/background_task/job.nu";
            hash = "sha256-L+SrTstXey9WhT4gHD4Wu++HEIMsh1LaNjWd2ouRLjI=";
          }
        }
      '';
      shellAliases = config.home.shellAliases;
    };
    services.pueue = {
      enable = true;
      settings.shared.use_unix_socket = true;
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
        name = "adwaita-dark";
        package = pkgs.adwaita-qt;
      };
    };

    services.gpg-agent.enable = true;

    services.network-manager-applet.enable = true;
    services.blueberry.enable = true;
    services.mpris-proxy.enable = true;
    services.flameshot = {
      enable = true;
      package = pkgs.flameshot.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs ++ [ pkgs.libsForQt5.kguiaddons ];
        cmakeFlags = [ "-DUSE_WAYLAND_CLIPBOARD=true" ];
      });
      settings = {
        General = {
          showDesktopNotification = false;
          showStartupLaunchMessage = false;
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

    services.xsettingsd.enable = true;
    services.xsettingsd.settings = {
      "Net/ThemeName" = "Adwaita-dark";
      "Xft/Antialias" = true;
      "Xft/Hinting" = true;
      "Xft/RGBA" = "rgb";
    };
    programs.kitty = {
      themeFile = "adwaita_dark";
      keybindings."ctrl+shift+n" = "new_os_window_with_cwd";
      settings = {
        scrollback_lines = 10000;
        enable_audio_bell = false;
        update_check_interval = 0;
      };
    };

    services.xssproxy.enable = false;
    services.lxqt-policykit-agent.enable = false;
    services.polkit-gnome.enable = true;
    services.hyprpolkitagent.enable = false;

    services.pasystray.enable = true;

    xdg.enable = true;
    # news.display = "silent";

    home.pointerCursor = {
      x11.enable = true;
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
      userName = "Bob van der Linden";
      userEmail = "bobvanderlinden@gmail.com";

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

      difftastic.enable = true;
      aliases = {
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
      ignores = [
        "vendor"
        "workspace.code-workspace"

        # Always ignore devenv.sh temporary files.
        ".devenv"
        ".devenv.flake.nix"
      ];
      extraConfig = {
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
        rebase.updateRefs = true;

        # Show original in-between ours and theirs.
        merge.conflictstyle = "zdiff3";

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
    programs.mergiraf.enable = true;
    programs.gh = {
      enable = true;
      settings = {
        # See https://github.com/nix-community/home-manager/issues/4744
        version = "1";
        editor = "code --wait";
      };
    };
    programs.jq.enable = true;
    programs.neovim.enable = true;
    programs.nix-index.enable = true;
    home.sessionVariables = {
      BROWSER = "chromium";
      EDITOR = "code --wait";
    };
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;

      # Store .envrc files outside of project directories.
      # Source: https://github.com/nix-community/nix-direnv#storing-direnv-outside-the-project-directory
      stdlib = builtins.readFile ./direnvrc;
    };
    programs.htop.enable = true;

    home.stateVersion = "21.03";
  };
}
