{pkgs, ...}: let
  vscode = pkgs.vscode;
  pulseaudio = pkgs.pulseaudioFull;
in {
  imports = [
    ./modules/blueberry.nix
    ./modules/lxqt-policykit-agent.nix
    ./modules/xssproxy.nix
  ];
  config = {
    home.packages = with pkgs; [
      coin
      hello
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
      rxvt_unicode-with-plugins
      xsel
      lxappearance
      gitAndTools.hub
      gitAndTools.gh
      git-cola
      git-branchless
      gnome3.file-roller
      clang
      slack
      zoom-us
      watchman
      i3status
      mono
      inconsolata
      liberation_ttf
      terminus_font
      ttf_bitstream_vera
      powerline-fonts
      gnupg
      vlc
      webtorrent_desktop
      patchelf
      docker-compose
      httpie
      gimp
      feh
      screen
      nix-review
      vscode
      leafpad
      dejavu_fonts
      mypaint
      tiled
      maven
      yq-go
      ripgrep
      gnome3.pomodoro
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
          font = "DejaVu Sans Mono for Powerline 11";
          foreground_color = "#839496";
          show_titlebar = false;
          scrollback_lines = 5000;
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
        package = pkgs.gnome3.adwaita-icon-theme;
      };
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome3.gnome-themes-extra;
      };
      gtk2.extraConfig = ''
        gtk-error-bell = 0
      '';

      gtk3.extraConfig = {gtk-error-bell = 0;};
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
    programs.zsh = {
      enable = true;
      enableAutosuggestions = true;
      history.extended = true;
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git-extras"
          "git"
          "gitfast"
          "github"
          "ssh-agent"
          "gpg-agent"
        ];
      };
      loginExtra = ''
        setopt extendedglob
        xset b off
        xset b 0 0 0
        source $HOME/.aliases
        bindkey '^R' history-incremental-pattern-search-backward
        bindkey '^F' history-incremental-pattern-search-forward
        eval "$(rbenv init -)"
      '';
    };
    programs.starship = {
      enable = true;
      enableZshIntegration = true;
    };
    qt = {
      enable = true;
      platformTheme = "gtk";
    };

    services.gnome-keyring.enable = true;
    services.gpg-agent.enable = true;
    services.keybase.enable = true;
    services.network-manager-applet.enable = true;
    services.blueberry.enable = true;
    services.mpris-proxy.enable = true;
    services.flameshot.enable = true;
    services.redshift = {
      enable = true;
      latitude = "51.985104";
      longitude = "5.898730";
      temperature.day = 5500;
      temperature.night = 3700;
      tray = true;
    };

    services.xssproxy.enable = false;
    services.lxqt-policykit-agent.enable = true;

    services.pasystray.enable = true;

    systemd.user.services.bitwarden = {
      Unit = {
        Description = "Bitwarden";
        After = ["graphical-session-pre.target"];
        PartOf = ["graphical-session.target"];
      };

      Install = {WantedBy = ["graphical-session.target"];};

      Service = {ExecStart = "${pkgs.bitwarden}/bin/bitwarden";};
    };

    xdg.enable = true;
    # news.display = "silent";

    home.pointerCursor = {
      x11.enable = true;
      name = "Vanilla-DMZ";
      package = pkgs.vanilla-dmz;
      size = 128;
    };

    programs.git = {
      enable = true;
      userName = "Bob van der Linden";
      userEmail = "bobvanderlinden@gmail.com";
      signing.signByDefault = true;
      signing.key = "EEBE8E3EC4A31364";
      delta.enable = true;
      aliases = {
        unstage = "reset HEAD --";
        pr = "pull --rebase";
        addp = "add --patch";
        comp = "commit --patch";
        co = "checkout";
        ci = "commit";
        c = "commit";
        b = "branch";
        p = "push";
        d = "diff";
        a = "add";
        s = "status";
        f = "fetch";
        br = "branch";
        pa = "add --patch";
        pc = "commit --patch";
        rf = "reflog";
        l = "log --graph --pretty='%Cred%h%Creset - %C(bold blue)<%an>%Creset %s%C(yellow)%d%Creset %Cgreen(%cr)' --abbrev-commit --date=relative";
        pp = "!git push --set-upstream origin $(git rev-parse --abbrev-ref HEAD)";
        recent-branches = "branch --sort=-committerdate";
      };
      ignores = [
        ".direnv"
        "flake.nix"
        "flake.lock"
        ".envrc"
        "vendor"
        "workspace.code-workspace"
      ];
      extraConfig = {
        core.editor = "${vscode}/bin/code --wait";
        merge.conflictstyle = "diff3";
        push.default = "current";
        pull.rebase = false;
        init.defaultBranch = "master";
        core.excludesfile = "~/.config/git/ignore";
        url."git@github.com:".insteadOf = "https://github.com/";
      };
    };
    programs.gh.enable = true;
    programs.jq.enable = true;
    programs.neovim.enable = true;
    home.sessionVariables = {
      BROWSER = "chromium";
    };
    programs.autorandr.enable = true;
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;

      # Store .envrc files outside of project directories.
      # Source: https://github.com/nix-community/nix-direnv#storing-direnv-outside-the-project-directory
      stdlib = builtins.readFile ./direnvrc;
    };
    programs.htop.enable = true;
    programs.home-manager.enable = true;

    home.stateVersion = "21.03";
  };
}
