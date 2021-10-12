{ lib, config, pkgs, ... }:
with lib;
let
  daemonJsonContent = builtins.toJSON config.virtualisation.docker.config;
  daemonJson = pkgs.writeText "daemon.json" daemonJsonContent;
in
{
  options.virtualisation.docker = {
    config = mkOption {
      type = types.attrs;
      default = { };
      example = {
        ipv6 = true;
        "fixed-cidr-v6" = "fd00::/80";
      };
      description = ''
        Configuration for docker daemon. The attributes are serialized to JSON used as daemon.conf as-is.
        Note that /etc/docker/daemon.conf will not be available anymore.
      '';
    };
  };
  config = {
    virtualisation.docker.config.ipv6 = true;
    virtualisation.docker.config."fixed-cidr-v6" = "fd00::/80";
    virtualisation.docker.extraOptions = "--config-file=${daemonJson}";
  };
}
