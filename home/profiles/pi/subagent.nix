{
  config,
  lib,
  pkgs,
  ...
}:
let
  piConfig = config.programs.pi-coding-agent;
  cfg = piConfig.subagent;
  json = pkgs.formats.json { };
in
{
  options.programs.pi-coding-agent.subagent = {
    settings = lib.mkOption {
      type = json.type;
      default = { };
      description = ''
        Settings written to Pi subagents' {file}`config.json`.
      '';
    };
  };

  config = lib.mkIf piConfig.enable {
    home.file."${piConfig.configDir}/extensions/subagent/config.json".source =
      json.generate "pi-subagent-config.json" cfg.settings;
  };
}
