{ lib, pkgs, ... }:
{
  # Create an env file for NetworkManager-ensure-profiles to inject the WireGuard
  # private key into the connection profile. The key lives at /etc/wireguard/private.key
  # (mode 600, root-owned) and is not stored in the Nix store.
  systemd.services."wireguard-nm-env" = {
    description = "Prepare WireGuard private key env file for NetworkManager";
    wantedBy = [ "NetworkManager-ensure-profiles.service" ];
    before = [ "NetworkManager-ensure-profiles.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0177";
    };
    script = ''
      echo "WG_PRIVATE_KEY=$(cat /etc/wireguard/private.key)" > /run/wireguard-nm-env
    '';
  };

  # Declare the WireGuard connection as a NetworkManager profile.
  # This makes it appear in nm-applet and allows manual connect/disconnect.
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ "/run/wireguard-nm-env" ];
    profiles."home-vpn" = {
      connection = {
        id = "home-vpn";
        type = "wireguard";
        interface-name = "wg0";
        autoconnect = "false";
      };
      wireguard = {
        private-key = "\${WG_PRIVATE_KEY}";
      };
      "wireguard-peer.qtWWK3BOXDeOucN76ad5e+dEEH3kCZWz3zeZIM2rjj0=" = {
        # rpi1
        endpoint = "home.bobvanderlinden.nl:51820";
        allowed-ips = "10.100.0.0/24;";
        persistent-keepalive = "25";
      };
      ipv4 = {
        method = "manual";
        addresses = "10.100.0.11/24";
        # Route only *.home.bobvanderlinden.nl queries through VPN DNS.
        dns = "10.100.0.1;";
        dns-search = "~home.bobvanderlinden.nl;";
      };
      ipv6 = {
        method = "disabled";
      };
    };
  };

}
