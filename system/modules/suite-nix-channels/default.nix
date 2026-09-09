# Makes sure the `nixpkgs` channel follows the nixpkgs input of this flake.
{ pkgs, ... }:
{
  nix.nixPath = [ "nixpkgs=/run/current-system/nixpkgs" ];
  system.systemBuilderCommands = ''
    ln -sv ${pkgs.path} $out/nixpkgs
  '';
}
