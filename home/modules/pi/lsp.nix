{
  config,
  lib,
  pkgs,
  ...
}:
let
  piConfig = config.programs.pi-coding-agent;
  cfg = piConfig.lsp;
  json = pkgs.formats.json { };
in
{
  options.programs.pi-coding-agent.lsp = {
    settings = lib.mkOption {
      type = json.type;
      default = { };
      description = ''
        Language servers and file extension mappings for Pi's LSP extension.
      '';
    };
  };

  config = lib.mkIf piConfig.enable {
    home.file."${piConfig.configDir}/lsp.json".source =
      json.generate "pi-lsp-config.json" cfg.settings;
  };
}
