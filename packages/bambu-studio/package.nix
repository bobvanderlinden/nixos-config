{
  lib,
  appimageTools,
  fetchurl,
  cacert,
  glib-networking,
}:

# Packaged from the upstream AppImage rather than building from source, since
# the nixpkgs build suffers from a display issue and a std::locale crash on
# exit. See https://discourse.nixos.org/t/bambu-studio-any-working-method/62272/29
#
# Note: you may need to clear the `language` key in
# `~/.config/BambuStudio/BambuStudio.conf` when migrating from the nixpkgs
# build, as it leaves the value set to `en` which this AppImage interprets as
# `en_GB` and fails to load.
appimageTools.wrapType2 rec {
  pname = "bambu-studio";
  version = "02.07.01.62";

  src = fetchurl {
    url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/BambuStudio_ubuntu24.04-v${version}-20260616195227.AppImage";
    hash = "sha256-+pi2CFMt+7uysJMUg6rEHlf7GcF1osx719Uo1eD7soc=";
  };

  profile = ''
    export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
    export GIO_MODULE_DIR="${glib-networking}/lib/gio/modules/"
  '';

  extraPkgs =
    pkgs: with pkgs; [
      cacert
      glib
      glib-networking
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      webkitgtk_4_1
    ];

  meta = {
    description = "PC software for the Bambu Lab 3D printers";
    homepage = "https://github.com/bambulab/BambuStudio";
    license = lib.licenses.agpl3Only;
    maintainers = [ lib.maintainers.bobvanderlinden ];
    mainProgram = "bambu-studio";
    platforms = [ "x86_64-linux" ];
  };
}
