{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nono;
  jsonFormat = pkgs.formats.json { };
  piProfile = jsonFormat.generate "nono-pi.json" cfg.pi.settings;
  sandboxedPi = pkgs.symlinkJoin {
    name = "pi-nono-${lib.getVersion cfg.pi.package}";
    paths = [ cfg.pi.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/pi"
      makeWrapper ${lib.getExe cfg.package} "$out/bin/pi" \
        --add-flags ${
          lib.escapeShellArg (
            lib.escapeShellArgs [
              "run"
              "--profile"
              piProfile
              "--allow-cwd"
              "--"
              (lib.getExe cfg.pi.package)
            ]
          )
        }
    '';
    meta = cfg.pi.package.meta // {
      mainProgram = "pi";
    };
  };
in
{
  options.programs.nono = {
    enable = lib.mkEnableOption "nono sandboxing";
    package = lib.mkPackageOption pkgs "nono" { };

    pi = {
      enable = lib.mkEnableOption "running Pi inside nono";
      package = lib.mkPackageOption pkgs "pi" { };
      settings = lib.mkOption {
        inherit (jsonFormat) type;
        default = {
          extends = "default";
          meta = {
            name = "pi";
            description = "Pi with a writable workspace and Nix development tools";
          };
          groups.include = [
            "nix_runtime"
            "git_config"
            "user_caches_linux"
            "node_runtime"
          ];
          filesystem = {
            allow = [
              config.programs.pi-coding-agent.configDir
              "${config.xdg.dataHome}/pi"
              "${config.xdg.dataHome}/direnv"
            ];
            read = [ "/etc/static" ];
          };
          network.block = false;
          workdir.access = "readwrite";
        };
        description = ''
          Nono profile used by Pi. The current directory is writable and network
          access is allowed. Pi state, development caches, and Nix tools are
          accessible; nono's default sensitive-path restrictions still apply.
          Child processes inherit the sandbox. Add paths here for worktrees or
          project dependencies outside the current directory.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];
    })
    (lib.mkIf cfg.pi.enable {
      programs.nono.enable = true;
      programs.pi-coding-agent.package = sandboxedPi;
      xdg.configFile."nono/profiles/pi.json".source = piProfile;
      assertions = [
        {
          assertion = config.programs.pi-coding-agent.enable;
          message = "programs.nono.pi.enable requires programs.pi-coding-agent.enable.";
        }
      ];
    })
  ];
}
