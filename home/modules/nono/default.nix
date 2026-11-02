{
  config,
  impurity,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nono;
  jsonFormat = pkgs.formats.json { };
  piProfile = jsonFormat.generate "nono-pi.json" cfg.pi.settings;
  launcher = pkgs.writeShellApplication {
    name = "pi-nono";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      workspace="$(pwd -P)"
      case "$workspace" in
        /|/home|"$HOME")
          echo "Start Pi inside a project, not $workspace." >&2
          exit 1
          ;;
      esac

      # Discover ancestor instructions and skills without exposing sibling projects.
      grants=()
      directory="$workspace"
      while true; do
        for resource in "$directory/.agents/skills" "$directory/AGENTS.md" "$directory/CLAUDE.md"; do
          if [[ -d "$resource" ]]; then
            grants+=(--read "$resource")
          elif [[ -f "$resource" ]]; then
            grants+=(--read-file "$resource")
          fi
        done
        [[ "$directory" == / ]] && break
        directory="$(dirname "$directory")"
      done
      if [[ -d "$HOME/.agents/skills" ]]; then
        grants+=(--read "$HOME/.agents/skills")
      fi

      # Use the patched Nix even before the system configuration is switched.
      export PI_NONO_NIX_BIN="${lib.makeBinPath [ pkgs.determinate-nix ]}"
      export PATH="$PI_NONO_NIX_BIN:$PATH"
      export DOCKER_HOST="''${DOCKER_HOST:-unix://''${XDG_RUNTIME_DIR:?}/docker.sock}"
      exec ${lib.getExe cfg.package} run --profile ${piProfile} --allow-cwd \
        "''${grants[@]}" -- ${lib.getExe cfg.pi.package} "$@"
    '';
  };
  sandboxedPi = pkgs.symlinkJoin {
    name = "pi-nono-${lib.getVersion cfg.pi.package}";
    paths = [ cfg.pi.package ];
    postBuild = ''
      rm -f "$out/bin/pi" "$out/bin/pi-bolt"
      ln -s ${lib.getExe launcher} "$out/bin/pi"
      ln -s pi "$out/bin/pi-bolt"
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
      enable = lib.mkEnableOption "running Pi and Pi-Bolt inside nono";
      package = lib.mkPackageOption pkgs "pi" { };
      settings = lib.mkOption {
        inherit (jsonFormat) type;
        default = {
          extends = "default";
          meta = {
            name = "pi";
            description = "Pi with a writable project, Nix, rootless Docker, and 1Password CLI";
          };
          groups.include = [
            "nix_runtime"
            "git_config"
            "node_runtime"
          ];
          workdir.access = "readwrite";
          linux.af_unix_mediation = "pathname";
          filesystem = {
            allow = [
              config.programs.pi-coding-agent.configDir
              "${config.xdg.dataHome}/pi"
              "${config.xdg.dataHome}/direnv"
              "${config.xdg.stateHome}/nix"
              "${config.xdg.cacheHome}/nix"
              "${config.xdg.cacheHome}/direnv"
              "${config.xdg.cacheHome}/uv"
              "${config.xdg.cacheHome}/node"
              "/tmp/pi-subagents-uid-$UID"
            ];
            allow_file = [ "$XDG_RUNTIME_DIR/op-daemon.pid" ];
            read = [
              (toString (impurity.link ../../profiles/pi))
              "/etc/static"
              "/etc/nix"
              "/run/wrappers"
              "${config.xdg.configHome}/direnv"
              "${config.xdg.configHome}/op"
              "${config.xdg.configHome}/git"
            ];
            read_file = [ "${config.xdg.configHome}/1Password/settings/settings.json" ];
            bypass_protection = [
              "${config.xdg.configHome}/op"
              "${config.xdg.configHome}/1Password/settings/settings.json"
            ];
            unix_socket = [
              "/nix/var/nix/daemon-socket/socket"
              "$XDG_RUNTIME_DIR/docker.sock"
              "$XDG_RUNTIME_DIR/op-daemon.sock"
              "$XDG_RUNTIME_DIR/s.sock"
              "$XDG_RUNTIME_DIR/1Password-BrowserSupport.sock"
            ];
          };
          network.block = false;
        };
        description = ''
          Nono profile for the Pi CLI. Docker and 1Password access are deliberate
          exceptions, not isolation from containers or credentials. Network access
          and Pi state writes remain allowed. Pi-web embeds the SDK and is not wrapped.
        '';
      };
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable { home.packages = [ cfg.package ]; })
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
