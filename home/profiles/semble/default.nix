{
  config,
  pkgs,
  ...
}:
let
  piConfigDir = config.programs.pi-coding-agent.configDir;
  sembleSkill = "${pkgs.semble.src}/src/semble/agents/pi.md";
in
{
  programs.pi-coding-agent.extraPackages = [ pkgs.semble ];

  home.packages = [ pkgs.semble ];

  home.file."${piConfigDir}/skills/semble-search.md" = {
    source = sembleSkill;
  };
}
