{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.phonon;
  containerName = "phonon-${config.home.username}";
  docker = lib.getExe pkgs.docker;
in
{
  options.services.phonon = {
    enable = lib.mkEnableOption "a local Phonon-2 transcription server in Docker";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/fermionresearch/phonon-cpu:2.0.9";
      description = "Phonon CPU container image. Downloaded by Docker on first start.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8010;
      description = "Loopback port for the OpenAI-compatible transcription API.";
    };

    threads = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Number of CPU threads used for transcription.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.phonon = {
      Unit = {
        Description = "Local Phonon-2 transcription server";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        # Docker must be enabled on the host and accessible to this user.
        # Only publish on loopback. The model cache survives container removal.
        ExecStartPre = "-${docker} rm --force ${containerName}";
        ExecStart = lib.escapeShellArgs [
          docker
          "run"
          "--rm"
          "--name"
          containerName
          "--publish"
          "127.0.0.1:${toString cfg.port}:8000"
          "--volume"
          "${containerName}-cache:/home/phonon/.cache"
          cfg.image
          "serve"
          "phonon-2"
          "--host"
          "0.0.0.0"
          "--port"
          "8000"
          "--threads"
          (toString cfg.threads)
        ];
        ExecStop = "${docker} stop --time 20 ${containerName}";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 30;
        Slice = "session.slice";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
