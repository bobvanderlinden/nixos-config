{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.virtualisation.docker;
  daemonConfigJson = builtins.toJSON cfg.daemonConfig;
  daemonConfigFile = pkgs.writeText "daemon.json" daemonConfigJson;
in {
  options.virtualisation.docker = {
    daemonConfig = mkOption {
      type = types.anything;
      default = {};
      example = {
        ipv6 = true;
        "fixed-cidr-v6" = "fd00::/80";
      };
      description = ''
        Configuration for docker daemon. The attributes are serialized to JSON used as daemon.conf as-is.
        Note that /etc/docker/daemon.conf will not be available anymore.
      '';
    };
    ipv6 = mkOption {
      type = types.bool;
      default = config.networking.enableIPv6;
      defaultText = "config.networking.enableIPv6";
      description = "Whether to use IPv6.";
    };
  };
  config = {
    virtualisation.docker.daemonConfig = mkIf cfg.ipv6 {
      ipv6 = true;
      "fixed-cidr-v6" = "fd00::/80";
    };
    virtualisation.docker.extraOptions = "--config-file=${daemonConfigFile}";
  };
}
