{ pkgs, config, ... }:
let
  vscode-wrapper = pkgs.writeShellScriptBin "code" ''
    exec ${pkgs.sway-open}/bin/sway-open \
      --app_id code-url-handler \
      --new-window-argument="--new-window" \
      ${config.programs.vscode.package}/bin/code \
      "$@"
  '';
  chromium-wrapper = pkgs.writeShellScriptBin "chromium" ''
    exec ${pkgs.sway-open}/bin/sway-open \
      --app_id chromium_browser \
      --new-window-argument="--new-window" \
      ${config.programs.chromium.package}/bin/chromium \
      "$@"
  '';
in
{
  imports = [
    ./modules/blueberry.nix
    ./modules/lxqt-policykit-agent.nix
    ./modules/xssproxy.nix
    ./modules/nushell.nix
  ];
  config = {
    home.packages = with pkgs; [
      coin
      nixfmt
      bitwarden
      insomnia
      spotify
      pavucontrol
      fortune
      cowsay
      gdb
      mplayer
      imagemagick
      nodejs
      entr
      socat
      file
      proot
      qemu
      awscli
      darkhttpd
      xclip
      jq
      nmap
      graphviz
      xfce.thunar
      xfce.xfconf
      xfce.tumbler
      xfce.exo
      volumeicon
      keepassxc
      jdk
      libreoffice
      speedcrunch
      ffmpegthumbnailer
      networkmanagerapplet
      xsel
      lxappearance

      gitAndTools.hub
      gitAndTools.gh
      git-cola
      git-branchless
      git-absorb
      git-revise

      gnome.file-roller
      clang
      slack
      zoom-us
      watchman
      i3status
      mono
      inconsolata
      liberation_ttf
      ttf_bitstream_vera
      gnupg
      vlc
      patchelf
      docker-compose
      httpie
      gimp
      feh
      screen
      nixpkgs-review
      leafpad
      mypaint
      tiled
      maven
      yq-go
      ripgrep
      gnome.pomodoro
      audacity
      ffmpeg-full
      zoxide
      fd
      procs
      sd
      bottom
      # neo4j-desktop
      watchexec
      bitwarden-cli
      xsv
      q-text-as-data
      httpie
      delta
      # luakit
      nodePackages.zx
      deno
      # jujutsu
      procs
      element-desktop
      thunderbird
      inkscape
      git-worktree-shell
      # monado
      meld
      lsof
      home-manager
      difftastic
      du-dust
      fx
      peek
      cachix
      tig
      dua
      chatgpt-cli
      helix
      nix-output-monitor
      xdg-utils
      # Prioritize the sway-open-wrappers.
      (lib.hiPrio chromium-wrapper)
      (lib.hiPrio vscode-wrapper)
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

    programs.chromium = {
      enable = true;
      commandLineArgs = [
        "--enable-features=WebUIDarkMode,CSSColorSchemeUARendering"
        "--force-dark-mode"
        # "--disable-gpu-driver-bug-workarounds"
        # "--ignore-gpu-blocklist"
        # "--enable-gpu-rasterization"
        # "--enable-zero-copy"
        # "--enable-features=VaapiVideoDecoder"
      ];
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
        package = pkgs.gnome.adwaita-icon-theme;
      };
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome.gnome-themes-extra;
      };
      gtk2.extraConfig = ''
        gtk-error-bell = 0
      '';

      gtk3.extraConfig = { gtk-error-bell = 0; };
    };
    programs.ssh = {
      enable = true;

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
          extraOptions."VerifyHostKeyDNS" = "no";
          extraOptions."ProxyJump" = "beheer1.ioservice.net";
        };

        "127.0.0.1" = {
          user = "bob.vanderlinden";
          forwardAgent = false;
          identityFile = "~/.ssh/nedap_rsa";
          extraOptions."VerifyHostKeyDNS" = "no";
        };

        "github.com" = {
          user = "git";
          identityFile = "~/.ssh/github_ed25519";
        };
      };

      forwardAgent = false;
      serverAliveInterval = 180;
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
        source ${pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/nushell/nu_scripts/e3b02b38eeece7c4ab8c20198cd36c6b12d5c3e4/background_task/job.nu";
          hash = "sha256-L+SrTstXey9WhT4gHD4Wu++HEIMsh1LaNjWd2ouRLjI=";
        }}
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
    programs.carapace.enable = true;
    qt = {
      enable = true;
      platformTheme = "gnome";
      style = {
        name = "adwaita-dark";
        package = pkgs.adwaita-qt;
      };
    };

    services.gpg-agent.enable = true;
    services.gpg-agent.pinentryFlavor = "gnome3";

    services.network-manager-applet.enable = true;
    services.blueberry.enable = true;
    services.mpris-proxy.enable = true;
    services.flameshot.enable = true;
    services.darkman = {
      enable = true;
      settings = {
        latitude = "51.985104";
        longitude = "5.898730";
        usegeoclue = true;
      };
    };
    services.redshift = {
      enable = true;
      latitude = "51.985104";
      longitude = "5.898730";
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

    services.xssproxy.enable = false;
    services.lxqt-policykit-agent.enable = true;

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
      userName = "Bob van der Linden";
      userEmail = "bobvanderlinden@gmail.com";
      signing.signByDefault = true;
      delta.enable = true;
      aliases = {
        unstage = "reset HEAD --";
        co = "checkout";
        c = "commit";
        b = "branch";
        p = "push";
        d = "diff";
        a = "add";
        s = "status";
        f = "fetch";
        t = "tag";
        l = "log --graph --pretty='%Cred%h%Creset - %C(bold blue)<%an>%Creset %s%C(yellow)%d%Creset %Cgreen(%cr)' --abbrev-commit --date=relative";
        fixup = "commit --fixup";
        pr-diff = "diff upstream/HEAD..";
        pr-log = "l upstream/HEAD..";
        pr-edit = "rebase --interactive --autosquash --rerere-autoupdate --rebase-merges --fork-point upstream/HEAD";
        pr-clean = "-c sequence.editor=true rebase --interactive --autosquash --rerere-autoupdate --empty drop --no-keep-empty --fork-point upstream/HEAD";
        pr-update = "pull --rebase=merges upstream HEAD";
      };
      ignores = [
        "vendor"
        "workspace.code-workspace"
      ];
      extraConfig = {
        core.editor = "code --wait";
        diff.external = "${pkgs.difftastic}/bin/difft";
        merge.conflictstyle = "diff3";
        push.default = "current";
        pull.rebase = false;
        init.defaultBranch = "master";
        url."git@github.com:".insteadOf = "https://github.com/";
        branch.sort = "-committerdate";
        tag.sort = "-v:refname";

        # Avoid hint: use --reapply-cherry-picks to include skipped commits
        advice.skippedCherryPicks = false;

        # Source: https://github.com/rust-lang/cargo/issues/3381#issuecomment-1193730972
        # avoid issues where the cargo-edit tool tries to clone from a repo you do not have WRITE access to.
        # we already use SSH for every github repo, and so this puts the clone back to using HTTPS.
        url."https://github.com/rust-lang/crates.io-index".insteadOf = "https://github.com/rust-lang/crates.io-index";

        # avoid issues where the `cargo audit` command tries to clone from a repo you do not have WRITE access to.
        # we already use SSH for every github repo, and so this puts the clone back to using HTTPS.
        url."https://github.com/RustSec/advisory-db".insteadOf = "https://github.com/RustSec/advisory-db";
      };
    };
    programs.vscode = {
      enable = true;
    };
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

