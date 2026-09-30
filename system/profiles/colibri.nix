{ pkgs, ... }:
let
  colibriGlmServer = pkgs.writeShellApplication {
    name = "colibri-glm-server";
    runtimeInputs = [
      pkgs.colibri
      pkgs.python3Packages.huggingface-hub
    ];
    text = ''
      model_path="$STATE_DIRECTORY/glm-5.2"
      model_repository="mastouri/GLM-5.2-colibri-int4-g64-with-int8-mtp"
      completed_marker="$model_path/.download-complete"

      if [[ ! -f "$completed_marker" ]]; then
        mkdir --parents "$model_path"
        hf download "$model_repository" --local-dir "$model_path"
        touch "$completed_marker"
      fi

      export COLI_API_KEY=local
      exec coli serve \
        --host 127.0.0.1 \
        --port 8081 \
        --ctx 32768 \
        --model "$model_path" \
        --model-id glm-5.2-colibri
    '';
  };
in
{
  systemd.services.colibri-glm = {
    description = "Colibri server for GLM-5.2";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      DynamicUser = true;
      ExecStart = "${colibriGlmServer}/bin/colibri-glm-server";
      Restart = "on-failure";
      RestartSec = "15s";
      StateDirectory = "colibri-glm";
      TimeoutStartSec = "infinity";
    };
  };
}
