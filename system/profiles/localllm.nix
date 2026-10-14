{ config, pkgs, ... }:
let
  strataQwenServer = pkgs.writeShellApplication {
    name = "strata-qwen-server";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.strata
      config.hardware.nvidia.package
    ];
    text = ''
      export HOME="$STATE_DIRECTORY"
      export XDG_CONFIG_HOME="$STATE_DIRECTORY/config"
      export XDG_CACHE_HOME="$STATE_DIRECTORY/cache"
      runtime_directory="$STATE_DIRECTORY/runtime"
      model_config="$runtime_directory/strata-iq2_xs.json"

      mkdir --parents "$runtime_directory"
      cp --recursive --no-preserve=mode ${pkgs.strata}/share/strata/. "$runtime_directory/"
      cd "$runtime_directory"

      # Setup downloads and verifies the pinned model and prepares its expert pack.
      # The Nix package supplies Python dependencies and the CUDA engine.
      if [[ ! -f "$model_config" ]]; then
        strata-setup \
          --setup \
          --yes \
          --family qwen \
          --model IQ2_XS \
          --context 32768 \
          --vision no \
          --backend cuda \
          --data-dir "$STATE_DIRECTORY/data" \
          --vram-reserve-mib 2048 \
          --host 127.0.0.1 \
          --port 8080 \
          --no-browser \
          --no-start
      fi

      # Keep dictation non-thinking unless a client explicitly requests reasoning.
      jq \
        --arg engine "${pkgs.strata}/libexec/strata/engine/strata" \
        '.exe = $engine | .reasoning_effort = "none" | .open_browser = false' \
        "$model_config" > "$model_config.next"
      mv "$model_config.next" "$model_config"

      exec strata-server --config "$model_config" --host 127.0.0.1 --port 8080
    '';
  };
in
{
  systemd.services.strata-qwen = {
    description = "Strata server for Qwen3.8-Flash-Next IQ2_XS";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      PYTHONUNBUFFERED = "1";
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    };

    serviceConfig = {
      DynamicUser = true;
      ExecStart = "${strataQwenServer}/bin/strata-qwen-server";
      Restart = "on-failure";
      RestartSec = "30s";
      StateDirectory = "strata-qwen";
      LimitMEMLOCK = "infinity";
      TimeoutStartSec = "infinity";
      TimeoutStopSec = "120s";
    };
  };
}
