{ config, pkgs, ... }:
{
  services.udev.extraRules = ''
    # Valve USB devices
    #SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"
    # Steam Controller udev write access
    #KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess"

    # Valve HID devices over USB hidraw
    #KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0666"

    # Valve HID devices over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*28DE:*", MODE="0666"
  '';
}
