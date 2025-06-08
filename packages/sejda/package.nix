{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  ffmpeg,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libappindicator-gtk3,
  libdbusmenu,
  libdrm,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libxkbcommon,
  mesa,
  nss,
  pango,
  systemd,
  xdg-utils,
  xorg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sejda";
  version = "7.6.12";

  src = fetchurl {
    url = "https://downloads.sejda-cdn.com/sejda-desktop_${finalAttrs.version}_amd64.deb";
    hash = "sha256-VIkYo5th8rjg3svkOzynuIQBGc+saQFsgqc253sbPmE=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    ffmpeg
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    pango
    systemd
    mesa # for libgbm
    nss
    libuuid
    libdrm
    libnotify
    libsecret
    libpulseaudio
    libxkbcommon
    libappindicator-gtk3
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXScrnSaver
    xorg.libxshmfence
    xorg.libXtst
  ];

  runtimeDependencies = [
    (lib.getLib systemd)
    libnotify
    libdbusmenu
    xdg-utils
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -R "opt" "$out"
    cp -R "usr/share" "$out/share"
    chmod -R g-w "$out"

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/opt/sejda-desktop/sejda-desktop $out/bin/sejda-desktop \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.buildInputs}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      "''${gappsWrapperArgs[@]}"
    substituteInPlace $out/share/applications/sejda-desktop.desktop \
      --replace "/opt/sejda-desktop/sejda-desktop" "sejda-desktop"
  '';

  meta = {
    changelog = "https://www.sejda.com/desktop-release-notes";
    description = "Productive PDF software that you'll love to use";
    homepage = "https://www.sejda.com/desktop";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ bobvanderlinden ];
    platforms = lib.platforms.linux;
    mainProgram = "sejda-desktop";
  };
})
