local mod = "SUPER"
local background_color = "rgb(1a1b26)"

local function bind_mod(suffix, action, opts)
  hl.bind(mod .. " + " .. suffix, action, opts)
end

local function run(cmd)
  return hl.dsp.exec_cmd(cmd)
end

local function hyprctl_json(command)
  local pipe = io.popen(command)
  if pipe == nil then
    return nil
  end

  local output = pipe:read("*a")
  pipe:close()
  return output
end

local function active_workspace_json()
  return hyprctl_json("hyprctl -j activeworkspace")
end

hl.curve("subtle", {
  type = "bezier",
  points = {
    { 0.20, 0.90 },
    { 0.25, 1.00 },
  },
})

hl.animation({ leaf = "global", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "fade", enabled = false })
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "subtle", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "layers", enabled = false })

hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    layout = "scrolling",
    no_focus_fallback = false,
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    background_color = background_color,
  },
  scrolling = {
    direction = "right",
  },
})

hl.env("BROWSER", "chromium")
hl.env("EDITOR", "code --wait")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_DISABLE_RDD_SANDBOX", "1")
hl.env("NIXOS_OZONE_WL", "1")

hl.window_rule({
  match = { class = "jetbrains-.*", title = "^win(.*)" },
  no_initial_focus = true,
})
hl.window_rule({
  match = { class = "jetbrains-.*", float = true },
  size = { 672, 700 },
})
hl.window_rule({
  match = { class = "Zoom" },
  float = true,
  suppress_event = "maximize",
  pin = true,
  dim_around = false,
  decorate = false,
})
hl.window_rule({
  match = { class = "Bitwarden" },
  no_screen_share = true,
  workspace = "special:vault silent",
  rounding = 12,
})
hl.window_rule({
  match = { class = "1password" },
  no_screen_share = true,
  workspace = "special:vault silent",
  rounding = 12,
})
-- Keep the 1Password authentication prompt visible and focused, not the main window.
hl.window_rule({
  match = { class = "1password", title = "^1Password$", float = true },
  workspace = "unset",
  pin = true,
  stay_focused = true,
  focus_on_activate = true,
})
hl.window_rule({
  match = { class = "slack" },
  workspace = "special:slack silent",
})
hl.window_rule({
  match = { group = true },
  no_anim = true,
})

hl.workspace_rule({
  workspace = "special:vault",
  gaps_in = 10,
  gaps_out = 60,
  on_created_empty = [[sh -lc "bitwarden > /dev/null 2>&1 & 1password > /dev/null 2>&1 &"]],
})
hl.workspace_rule({
  workspace = "special:slack",
  gaps_in = 10,
  gaps_out = 60,
  on_created_empty = "slack",
})

hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start hyprland-session.target")
end)

hl.on("hyprland.shutdown", function()
  os.execute("systemctl --user stop hyprland-session.target && sleep 0.1")
end)

bind_mod("T", run("ghostty --working-directory=$HOME"))
bind_mod("W", run("chromium"))
bind_mod("E", run("thunar"))
bind_mod("Q", run("rofi -show combi -modes combi -combi-modes run,emoji -combi-hide-mode-prefix"))
bind_mod("Delete", run("loginctl lock-session"))
bind_mod("Print", run("flameshot gui"))
bind_mod("SHIFT + Print", run("wl-screenrecord"))
bind_mod("V", run("hyprwhspr-rs record start"))
bind_mod("V", run("hyprwhspr-rs record stop"), { release = true })
bind_mod("CTRL + V", run([[sh -lc 'selection=$(cliphist list | rofi -dmenu -p clipboard); [ -n "$selection" ] && printf %s "$selection" | cliphist decode | wl-copy']]))
bind_mod("C", hl.dsp.window.close())

bind_mod("H", hl.dsp.focus({ direction = "l" }))
bind_mod("J", hl.dsp.focus({ direction = "u" }))
bind_mod("K", hl.dsp.focus({ direction = "d" }))
bind_mod("L", hl.dsp.focus({ direction = "r" }))
bind_mod("Left", hl.dsp.focus({ direction = "l" }))
bind_mod("Up", hl.dsp.focus({ direction = "u" }))
bind_mod("Down", hl.dsp.focus({ direction = "d" }))
bind_mod("Right", hl.dsp.focus({ direction = "r" }))
bind_mod("Tab", hl.dsp.workspace.toggle_special("slack"))
bind_mod("SHIFT + Tab", hl.dsp.group.prev())

bind_mod("SHIFT + H", hl.dsp.window.move({ direction = "l" }))
bind_mod("SHIFT + K", hl.dsp.window.move({ direction = "u" }))
bind_mod("SHIFT + J", hl.dsp.window.move({ direction = "d" }))
bind_mod("SHIFT + L", hl.dsp.window.move({ direction = "r" }))
bind_mod("SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
bind_mod("SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
bind_mod("SHIFT + Down", hl.dsp.window.move({ direction = "d" }))
bind_mod("SHIFT + Right", hl.dsp.window.move({ direction = "r" }))

bind_mod("CTRL + Left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
bind_mod("CTRL + Down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }))
bind_mod("CTRL + Up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }))
bind_mod("CTRL + Right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))

bind_mod("G", hl.dsp.group.toggle())
bind_mod("F", hl.dsp.window.fullscreen({ mode = "maximized" }))
bind_mod("SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
bind_mod("S", run([[sh -lc 'active_workspace_json=$(hyprctl -j activeworkspace); ws_id=$(printf %s "$active_workspace_json" | jq --raw-output .id); current_layout=$(printf %s "$active_workspace_json" | jq --raw-output .tiledLayout); if [ "$current_layout" = scrolling ]; then exec hyprctl keyword workspace "$ws_id, layout:dwindle, gapsin:0, gapsout:0"; else exec hyprctl keyword workspace "$ws_id, layout:scrolling, layoutopt:direction:right, gapsin:8, gapsout:28"; fi']]))
bind_mod("comma", hl.dsp.layout("focus l"))
bind_mod("period", hl.dsp.layout("focus r"))
bind_mod("SHIFT + comma", hl.dsp.layout("swapcol l"))
bind_mod("SHIFT + period", hl.dsp.layout("swapcol r"))
bind_mod("P", hl.dsp.layout("promote"))

for i = 1, 9 do
  bind_mod(tostring(i), hl.dsp.focus({ workspace = tostring(i) }))
  bind_mod("SHIFT + " .. tostring(i), hl.dsp.window.move({ workspace = tostring(i) }))
  bind_mod("SHIFT + CTRL + " .. tostring(i), run("reassign-workspace " .. tostring(i)))
end
bind_mod("0", hl.dsp.focus({ workspace = "10" }))
bind_mod("SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))
bind_mod("SHIFT + CTRL + 0", run("reassign-workspace 10"))

bind_mod("grave", hl.dsp.workspace.toggle_special("vault"))
bind_mod("SHIFT + grave", hl.dsp.window.move({ workspace = "special:vault" }))
bind_mod("SHIFT + CTRL + ALT + Left", hl.dsp.workspace.move({ monitor = "l" }))
bind_mod("SHIFT + CTRL + ALT + Right", hl.dsp.workspace.move({ monitor = "r" }))
bind_mod("SHIFT + R", run("hyprctl reload"))

hl.bind("XF86AudioRaiseVolume", run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute", run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioPlay", run("playerctl play"))
hl.bind("XF86AudioPause", run("playerctl pause"))
hl.bind("XF86AudioNext", run("playerctl next"))
hl.bind("XF86AudioPrev", run("playerctl previous"))
hl.bind("XF86MonBrightnessUp", run("brightnessctl set 5%+"))
hl.bind("XF86MonBrightnessDown", run("brightnessctl set 5%-"))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("switch:[Lid Switch]", run("hyprlock"), { locked = true })
