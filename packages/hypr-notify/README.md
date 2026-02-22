# hypr-notify

Sends a persistent desktop notification that lets you click back to the terminal
it came from. Designed for long-running terminal commands (e.g. AI assistants,
builds) that finish while you have switched to another window.

## Usage

```
hypr-notify [--app-name NAME] [--bell] [--replace-id ID]
            [--window-address ADDRESS] [--verbose]
            SUMMARY [BODY]
```

When `--window-address` points to a Hyprland window:

- The notification stays open until you dismiss it or switch back to that window.
- Clicking the **Open** action on the notification focuses the window.
- Closing the window dismisses the notification automatically.

`--bell` writes the ASCII bell character (`\a`) to stderr. Terminal emulators
such as Ghostty respond to this by marking their window as
[urgent](https://wiki.hyprland.org/Configuring/Variables/#misc) in Hyprland,
which causes the window and its workspace to grab visual attention (e.g. a
highlight in the taskbar or workspace indicator).

## `HYPR_WINDOW_ADDRESS`

`--window-address` defaults to the `HYPR_WINDOW_ADDRESS` environment variable.
This variable should be set to the Hyprland address of the terminal window at
shell startup, so any command run inside that terminal can send a notification
that points back to it.

Example (Fish shell, Ghostty only):

```fish
# in interactiveShellInit
if test "$TERM_PROGRAM" = ghostty
    set -gx HYPR_WINDOW_ADDRESS (hyprctl activewindow -j | jq -r '.address')
end
```

With this in place, simply running:

```
hypr-notify "Build finished"
```

…from any command in that terminal will show a notification that, when clicked,
focuses the terminal window the command was run from.

## Nix

`HYPR_WINDOW_ADDRESS` is set in `home/default.nix` as part of the Fish shell
interactive init, and `hypr-notify` is invoked from the OpenCode notify plugin
(`opencode/plugins/notify.js`) to alert when an AI session goes idle.
