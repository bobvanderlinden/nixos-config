---
name: screenshot
description: Capture and inspect a region of the current Hyprland desktop when verifying visual UI changes.
---

# Screenshot verification

Use screenshots to verify visual changes in Quickshell or other desktop UI.

- Capture only the relevant region. Do not capture the full display unless the task requires the whole desktop.
- Run `hyprctl monitors -j` when you need the output geometry.
- Use `grim`. If it is unavailable, read the `nix` skill, then add the temporary `grim` package with `nix_session`.
- `grim -g` expects geometry as `"x,y widthxheight"`. For example, capture the top-left part of the display with:

  ```sh
  grim -g '0,0 520x180' /tmp/ui-check.png
  ```

- Inspect the resulting PNG with the `read` tool.
- Keep temporary screenshots under `/tmp`.
