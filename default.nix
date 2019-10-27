rec {
  nixpkgs = import <nixpkgs>;
  nixos = import <nixpkgs/nixos>;
  test = import <nixpkgs/nixos/tests/make-test.nix> (
    { pkgs, ...}:
    rec {
      name = "desktop";
      meta = {
        maintainers = [];
      };
      nodes = {
        machine =
          { pkgs, ... }:

          { imports = [ ./configuration.nix ];
            networking.hostName = pkgs.lib.mkForce "machine";
            swapDevices = pkgs.lib.mkForce [];
            boot = pkgs.lib.mkForce {};
          };
      };
      testScript = ''
        startAll;
        $machine->waitForX;
        $machine->sleep(10);
        $machine->screenshot("screen");
      '';
    }
  );
}
