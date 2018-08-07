# This will enable the `towindows` script to quickly
# reboot to Windows.
{ pkgs, ... }:
let
  towindows = pkgs.towindows;
in
{
  environment.systemPackages = [ towindows ];
  security.wrappers = {
    towindows = {
      program = "towindows";
      source = "${towindows}/bin/towindows";
      owner = "root";
      setuid = true;
    };
  };
}
