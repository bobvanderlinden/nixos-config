{ pkgs, ... }:
{
  # Keep the server ready while Ollama loads Qwen into GPU memory only when a
  # request needs it. The configured model download does not load the model.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    environmentVariables.OLLAMA_KEEP_ALIVE = "5m";
    loadModels = [ "qwen3:14b" ];
  };
}
