---
name: hyprctl
description: Inspect and change a running Hyprland session, especially monitor modes, scale, position, and transforms. Use when the user asks to fix displays with hyprctl. Uses Hyprland's Lua API rather than legacy configuration commands.
---

# Hyprctl

Use `hyprctl` to inspect the active Hyprland session and make live changes.

## Monitor changes

Inspect connected outputs, their native modes, logical positions, and scale before changing anything:

```bash
hyprctl monitors all
hyprctl -j monitors | jq '.[] | { name, description, width, height, refreshRate, x, y, scale, transform }'
```

On Lua-configured Hyprland, make monitor changes with `hyprctl eval` and `hl.monitor`. Do not use legacy configuration commands.

```bash
hyprctl eval 'hl.monitor({
  output = "DP-3",
  mode = "3840x2160@60",
  position = "0x0",
  scale = 2,
})'
```

`position` uses logical pixels. A display at 3840x2160 with scale 2 occupies 1920x1080 logical pixels. Position the next display at `1920x0` to place it immediately to the right:

```bash
hyprctl eval 'hl.monitor({
  output = "eDP-1",
  mode = "1920x1200@60",
  position = "1920x0",
  scale = 1,
})'
```

Set a rotated display with `transform`. The value `1` rotates it 90 degrees clockwise:

```bash
hyprctl eval 'hl.monitor({
  output = "DP-3",
  mode = "3840x2160@60",
  position = "0x0",
  scale = 2,
  transform = 1,
})'
```

Disable an output:

```bash
hyprctl eval 'hl.monitor({ output = "HDMI-A-1", disabled = true })'
```

Verify the result after every change:

```bash
hyprctl -j monitors | jq '.[] | { name, width, height, refreshRate, x, y, scale, transform, disabled }'
```

Live `hyprctl eval` changes do not survive a Hyprland reload. When a change must persist, add the same `hl.monitor({ ... })` rule to the active Hyprland Lua configuration.
