{ swaylock
, fetchFromGitHub
, dbus
, fprintd
, glib
}:
swaylock.overrideAttrs (oldAttrs: {
    src = fetchFromGitHub {
        owner = "SL-RU";
        repo = "swaylock-fprintd";
        rev = "ffd639a785df0b9f39e9a4d77b7c0d7ba0b8ef79";
        hash = "sha256-2VklrbolUV00djPt+ngUyU+YMnJLAHhD+CLZD1wH4ww=";
    };
    postPatch = ''
        substituteInPlace fingerprint/meson.build \
        --replace /usr/share/dbus-1/interfaces/ ${fprintd}/share/dbus-1/interfaces/
    '';
    buildInputs = oldAttrs.buildInputs ++ [
        dbus
        fprintd
        glib
    ];
})