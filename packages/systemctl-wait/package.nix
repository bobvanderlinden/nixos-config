{ python3Packages }:
python3Packages.buildPythonApplication {
  pname = "systemctl-wait";
  version = "0.1.0";
  pyproject = true;
  src = ./.;

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    dbus-fast
  ];
}
