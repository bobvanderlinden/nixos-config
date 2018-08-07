{ config, pkgs, ... }:
{
  services.xserver = {
        synaptics = {
      enable = true;
      accelFactor = "0.05";
      minSpeed = "1";
      maxSpeed = "1";
      twoFingerScroll = true;
      vertEdgeScroll = false;
      tapButtons = true;
      palmDetect = true;
      additionalOptions =
        ''
          # This sets the top area of the touchpad to not track
          # movement but can be used for left/middle/right clicks
          Option "SoftButtonAreas" "60% 0 0 2400 40% 60% 0 2400"
          Option "AreaTopEdge" "2400"

          # Helps to reduce mouse cursor "jumpiness"
          Option "HorizHysteresis" "30"
          Option "VertHysteresis" "30"

          # Settings reported to work well on an X1 Carbon
          Option "FingerLow" "40"
          Option "FingerHigh" "45"
          Option "AccelerationProfile" "2"
          Option "ConstantDeceleration" "4"

          Option "TapAndDragGesture" "1"

          # Enable three-finger tap for middle mouse click
          Option "TapButton3" "3"
          Option "TapButton2" "2"
        '';
      };
  };
}