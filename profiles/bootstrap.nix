{
  inputs,
  pkgs,
  ...
}:
{
  time.timeZone = "Europe/Amsterdam";

  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 3;

  suites.single-user.enable = true;
  users.defaultUserShell = pkgs.bashInteractive;

  networking.networkmanager.enable = true;
  services.resolved.enable = true;
  services.openssh.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # The installer ISO cannot hold the full desktop closure. Build it after the
  # first boot, when the encrypted root filesystem provides the Nix store.
  systemd.services.install-full-system = {
    description = "Install the full new-laptop configuration";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.nix ];
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "1min";
    };
    script = ''
      nixos-rebuild switch --flake github:bobvanderlinden/nixos-config/laptop-2026-09-04#new-laptop
    '';
  };
}
