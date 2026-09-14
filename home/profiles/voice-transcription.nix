{
  lib,
  pkgs,
  ...
}:
let
  whisperModel = pkgs.fetchurl {
    name = "ggml-large-v3-turbo-q8_0.bin";
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/0b364b566045a405be7225ee1e415a073e04da77/ggml-large-v3-turbo-q8_0.bin";
    hash = "sha256-MX62nBFnPJ3h4fDUWbJTmZgE7HGsTCPBfs9fviTiWaE=";
  };
  toml = pkgs.formats.toml { };
in
{
  home.packages = [ pkgs.voxtype-cuda ];

  xdg.configFile."voxtype/config.toml".source = toml.generate "voxtype-config.toml" {
    state_file = "auto";

    hotkey.enabled = false;

    audio = {
      device = "default";
      sample_rate = 16000;
      max_duration_secs = 60;
      feedback = {
        enabled = true;
        theme = "subtle";
        volume = 0.7;
      };
    };

    whisper = {
      mode = "local";
      model = toString whisperModel;
      language = "en";
      translate = false;
      on_demand_loading = false;
    };

    output = {
      mode = "type";
      fallback_to_clipboard = true;
      notification = {
        on_recording_start = false;
        on_recording_stop = false;
        on_transcription = true;
      };
    };

    text.spoken_punctuation = true;
    osd.enabled = false;
  };

  systemd.user.services.voxtype = {
    Unit = {
      Description = "Voxtype desktop dictation service";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    Service = {
      ExecStart = lib.getExe pkgs.voxtype-cuda;
      Restart = "on-failure";
      Slice = "session.slice";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
