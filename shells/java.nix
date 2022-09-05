{pkgs}:
with pkgs; {
  java-8 =
    mkShell {
      nativeBuildInputs = [
        maven
        jdk8
      ];
    };
}
