{
  config,
  pkgs,
  ...
}:
let
  whisperModel = pkgs.fetchurl {
    name = "ggml-large-v3-turbo-q8_0.bin";
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/0b364b566045a405be7225ee1e415a073e04da77/ggml-large-v3-turbo-q8_0.bin";
    hash = "sha256-MX62nBFnPJ3h4fDUWbJTmZgE7HGsTCPBfs9fviTiWaE=";
  };
in
{
  hyprwhspr-rs = {
    enable = true;
    whisperCpp = config.services.whisper-server.package;
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
        provider = "custom.local_whisper";
        custom.local_whisper = {
          kind = "openai_audio_transcriptions";
          label = "Persistent local Whisper";
          base_url.value = "http://127.0.0.1:${toString config.services.whisper-server.port}";
          endpoint = "/v1/audio/transcriptions";
          model = "large-v3-turbo-q8_0";
          audio_format = "wav";
          prompt = "Transcribe spoken text accurately with punctuation and capitalization. Return only the transcription.";
        };
      };
    };
    hyprland = {
      enable = false;
      holdKey = "$mod, V";
    };
  };

  services.whisper-server = {
    enable = true;
    package = pkgs.whisper-cpp.override {
      cudaSupport = true;
    };
    model = whisperModel;
  };

  systemd.user.services.hyprwhspr-rs.Unit.ConditionPathExists = whisperModel;
}
