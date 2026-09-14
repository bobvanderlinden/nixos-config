{ pkgs, ... }:
let
  llamaQwenServer = pkgs.writeShellApplication {
    name = "llama-qwen-server";
    runtimeInputs = [
      pkgs.curl
      pkgs.llama-cpp-cuda
    ];
    text = ''
      model_path="$STATE_DIRECTORY/Qwen3-14B-Q4_K_M.gguf"
      model_url="https://huggingface.co/Qwen/Qwen3-14B-GGUF/resolve/main/Qwen3-14B-Q4_K_M.gguf"

      if [[ ! -f "$model_path" ]]; then
        curl \
          --continue-at - \
          --fail \
          --location \
          --output "$model_path.part" \
          --retry 3 \
          "$model_url"
        mv "$model_path.part" "$model_path"
      fi

      exec llama-server \
        --alias qwen3:14b \
        --ctx-size 16384 \
        --host 127.0.0.1 \
        --model "$model_path" \
        --n-gpu-layers 999 \
        --port 8080
    '';
  };
in
{
  systemd.services.llama-qwen = {
    description = "llama.cpp server for Qwen3 14B";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      DynamicUser = true;
      ExecStart = "${llamaQwenServer}/bin/llama-qwen-server";
      Restart = "on-failure";
      RestartSec = "5s";
      StateDirectory = "llama-qwen";
    };
  };
}
