{
  config,
  lib,
  pkgs,
  ...
}:
let
  piConfigDir = config.programs.pi-coding-agent.configDir;
in
{
  home.packages = [ pkgs.pi-web ];
  home.file."${piConfigDir}/bin/pi-web".source = "${pkgs.pi-web}/bin/pi-web";

  home.activation.piWebToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    tokenDirectory="${config.xdg.configHome}/pi-web"
    if [ ! -e "$tokenDirectory/env" ]; then
      run mkdir -p "$tokenDirectory"
      run ${pkgs.bash}/bin/bash -c '
        umask 077
        printf "PI_WEB_TOKEN=%s\n" "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > "$1/env"
      ' -- "$tokenDirectory"
    fi
  '';

  systemd.user.services.pi-web = {
    Unit = {
      Description = "Pi Web session browser";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.pi-web}/bin/pi-web";
      EnvironmentFile = "${config.xdg.configHome}/pi-web/env";
      Environment = [
        "PATH=${lib.makeBinPath config.programs.pi-coding-agent.extraPackages}:%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
        "PI_OFFLINE=1"
      ];
      WorkingDirectory = config.home.homeDirectory;
      Restart = "on-failure";
      RestartSec = 5;
      SuccessExitStatus = [
        130
        143
      ];
      UMask = "0077";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
