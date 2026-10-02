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
  voxtypeCleanup = pkgs.writeShellApplication {
    name = "voxtype-cleanup";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      transcription="$(cat)"
      jq --null-input --arg transcription "$transcription" '{
        model: "qwen3.5:9b",
        stream: false,
        temperature: 0.2,
        max_tokens: 256,
        chat_template_kwargs: { enable_thinking: false },
        messages: [
          {
            role: "system",
            content: "You clean dictated text. Correct grammar, punctuation, and obvious transcription errors. Preserve the language, wording, meaning, and tone. Never add information. Output only the corrected text. Use this exact capitalization for recognized terminology when it fits the context: FHIR, HAPI FHIR, HL7, Voxtype, Nix, NixOS, LLM, OpenAPI, PostgreSQL, Hyprland, Nixpkgs, Home Manager."
          },
          {
            role: "user",
            content: $transcription
          }
        ]
      }' | curl \
        --fail \
        --silent \
        --show-error \
        --header 'Content-Type: application/json' \
        --data-binary @- \
        http://127.0.0.1:8080/v1/chat/completions | jq --exit-status --raw-output '.choices[0].message.content'
    '';
  };
in
{
  home.packages = [ pkgs.voxtype-cuda ];

  xdg.configFile."voxtype/config.toml" = {
    source = toml.generate "voxtype-config.toml" {
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
        # Restrict automatic language detection to the languages used for dictation.
        # This preserves Dutch and English instead of translating either language.
        language = [
          "nl"
          "en"
        ];
        initial_prompt = "Terminology: FHIR, HAPI FHIR, HL7, Voxtype, Nix, NixOS, LLM, OpenAPI, PostgreSQL, Hyprland, Nixpkgs, Home Manager.";
        translate = false;
        on_demand_loading = false;
      };

      output = {
        mode = "type";
        fallback_to_clipboard = true;
        post_process = {
          command = "${voxtypeCleanup}/bin/voxtype-cleanup";
          timeout_ms = 15000;
        };
        notification = {
          on_recording_start = false;
          on_recording_stop = false;
          on_transcription = false;
        };
      };

      text = {
        spoken_punctuation = true;
        replacements = {
          "vox type" = "Voxtype";
          "fox type" = "Voxtype";
          "nix os" = "NixOS";
          "hapi fhir" = "HAPI FHIR";
          "f h i r" = "FHIR";
          "l l m" = "LLM";
        };
      };
      osd = {
        enabled = true;
        frontend = "quickshell";
      };
    };

    # Voxtype reads its configuration only at startup.
    onChange = "${lib.getExe' pkgs.systemd "systemctl"} --user try-restart voxtype.service";
  };

  systemd.user.services.voxtype = {
    Unit = {
      Description = "Voxtype desktop dictation service";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    Service = {
      Environment = [
        "VOXTYPE_OSD_QML_PATH=${pkgs.voxtype-quickshell}/share/voxtype/quickshell"
      ];
      ExecStart = lib.getExe pkgs.voxtype-cuda;
      Restart = "on-failure";
      Slice = "session.slice";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
