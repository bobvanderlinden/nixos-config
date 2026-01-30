{
  lib,
  python3Packages,
  fetchFromGitHub,
  ydotool,
  xclip,
  wl-clipboard,
  pulseaudio,
}:

python3Packages.buildPythonApplication rec {
  pname = "voxd";
  version = "1.7.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jakovius";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-A02lNyBO0XkDL7rSG3rgTW/q6R4SqBkyTLr1GZV2NW8=";
  };

  # Patch the invalid version string in pyproject.toml
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'version = "mr.batman"' 'version = "${version}"'
  '';

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    sounddevice
    pyqt6
    platformdirs
    pyyaml
    pyperclip
    psutil
    numpy
    requests
    tqdm
    pyqtgraph
  ];

  # Runtime dependencies for clipboard and typing functionality
  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ ydotool xclip wl-clipboard pulseaudio ]}"
  ];

  # Skip tests as they may require audio devices or models
  doCheck = false;

  meta = with lib; {
    description = "Voice-typing helper powered by whisper.cpp for Linux";
    homepage = "https://github.com/jakovius/voxd";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "voxd";
    platforms = platforms.linux;
  };
}
