# This will enable colorful emoji characters from the EmojiOne package.
{ config, pkgs, ... }:
{
  fonts = {
    fonts = with pkgs; [
      noto-fonts noto-fonts-cjk noto-fonts-emoji
    ];

    # Source: https://github.com/wireapp/wire-desktop/wiki/Colorful-emojis-on-Linux
    fontconfig.localConf = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>

        <!-- Add emoji generic family -->
        <alias binding="strong">
          <family>emoji</family>
          <default><family>Noto Color Emoji</family></default>
        </alias>

        <!-- Aliases for the other emoji fonts -->
        <alias binding="strong">
          <family>Apple Color Emoji</family>
          <prefer><family>Noto Color Emoji</family></prefer>
        </alias>
        <alias binding="strong">
          <family>Segoe UI Emoji</family>
          <prefer><family>Noto Color Emoji</family></prefer>
        </alias>
        <alias binding="strong">
          <family>Emoji One</family>
          <prefer><family>Noto Color Emoji</family></prefer>
        </alias>

        <!-- Do not allow any app to use Symbola, ever -->
        <selectfont>
          <rejectfont>
            <pattern>
              <patelt name="family">
                <string>Symbola</string>
              </patelt>
            </pattern>
          </rejectfont>
        </selectfont>
      </fontconfig>
    '';
  };
}
