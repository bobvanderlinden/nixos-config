{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.fprintd.enable = lib.mkDefault true;
  services.gnome.gnome-keyring.enable = lib.mkDefault true;

  security.pam.services.login.fprintAuth = lib.mkDefault true;
  security.pam.services.greetd = {
    fprintAuth = lib.mkDefault true;
    enableGnomeKeyring = lib.mkDefault true;

    # Autologin skips greetd's auth stack, so inject the boot-time LUKS
    # password during PAM session setup before gnome-keyring starts.
    rules.session.fdeBootPassword = {
      order = config.security.pam.services.greetd.rules.session.login.order - 10;
      control = "optional";
      modulePath = "${pkgs.pam_fde_boot_pw}/lib/security/pam_fde_boot_pw.so";
      args = [ "inject_for=gkr" ];
    };
  };
}
