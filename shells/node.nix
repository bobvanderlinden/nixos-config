{pkgs, ...}:
with pkgs; {
  node-14 =
    mkShell {
      nativeBuildInputs = [
        nodejs-14_x
      ];
    };

  node-16 =
    mkShell {
      nativeBuildInputs = [
        nodejs-16_x
      ];
    };
}
