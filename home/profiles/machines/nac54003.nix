{ lib, ... }:
{
  # Host-specific Home Manager profile. Shared desktop defaults retain the
  # bottom status bar and native display scale on this laptop.
  xdg.configFile."uwsm/env".text = lib.mkAfter ''
    export LIBVA_DRIVER_NAME=nvidia
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export NVD_BACKEND=direct
  '';
}
