{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.whisper-server;
in
{
  options.services.whisper-server = {
    enable = lib.mkEnableOption "a persistent local whisper.cpp server";

    package = lib.mkPackageOption pkgs "whisper-cpp" { };

    model = lib.mkOption {
      type = lib.types.path;
      description = "Whisper model file served by whisper-server.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Local TCP port used by whisper-server.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.whisper-server = {
      Unit = {
        Description = "Persistent local Whisper transcription server";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe' cfg.package "whisper-server")
          "--model"
          (toString cfg.model)
          "--inference-path"
          "/v1/audio/transcriptions"
          "--port"
          (toString cfg.port)
        ];
        Restart = "on-failure";
        Slice = "session.slice";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
