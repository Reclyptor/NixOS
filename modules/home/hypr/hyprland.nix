_: {
  flake.modules.homeManager.base =
    { config, ... }:
    let
      inherit (config) palette;
    in
    {
      wayland.windowManager.hyprland = {
        enable = true;
        xwayland.enable = true;
        systemd.enable = true;

        # Hyprland 0.56 loads ~/.config/hypr/hyprland.lua and warns that the
        # legacy hyprland.conf fallback will stop being supported. Generate
        # Lua. `settings` stays empty: it renders hl.<name>(...) calls from
        # hyprlang-style strings, but the 0.56 Lua API dropped the comma-string
        # forms (binds take hl.dsp dispatchers, rules and monitors take
        # tables), so the config lives in extraLuaFiles as real Lua.
        configType = "lua";

        extraLuaFiles."00-hyprland" = {
          content = ''
-- Programs
local terminal    = "kitty"
local fileManager = "kitty yazi"
local browser     = "zen-beta"
local menu        = "pkill fuzzel || fuzzel"
local mainMod     = "SUPER"

-- Monitor: ultrawide 5120x1440@240, regardless of connector naming
hl.monitor({ output = "", mode = "5120x1440@240", position = "auto", scale = "1" })

-- Xwayland
hl.config({ xwayland = { force_zero_scaling = true } })

-- Environment variables
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("HYPRSHOT_DIR", "${config.home.homeDirectory}/Screenshots")

-- Autostart (home-manager adds its own hyprland-session.target hook)
hl.on("hyprland.start", function()
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11")
    hl.exec_cmd("nm-applet --indicator")
end)

-- Input
hl.config({
    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        repeat_delay = 200,
        repeat_rate  = 25,
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

-- General
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,
        col = {
            active_border   = "rgba(${palette.accent}FF)",
            inactive_border = "rgba(${palette.accent}4D)",
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },
})

-- Decoration
hl.config({
    decoration = {
        rounding         = 6,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 4,
            color        = "rgba(${palette.accent}33)",
        },
        blur = {
            enabled           = true,
            size              = 8,
            passes            = 3,
            new_optimizations = true,
            xray              = false,
            vibrancy          = 0.2,
            vibrancy_darkness = 0.5,
        },
    },
})

-- Animations
hl.config({ animations = { enabled = true } })

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1.0} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })
hl.curve("bounce",         { type = "bezier", points = { {0.34, 1.56}, {0.64, 1} } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5,    bezier = "bounce",       style = "popin 60%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4,    bezier = "easeOutQuint", style = "slidefade 30%" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 4,    bezier = "easeOutQuint", style = "slidefade 30%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4,    bezier = "easeOutQuint", style = "slidefade 30%" })

-- Layouts
hl.config({
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
})

-- Misc
hl.config({
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
        vrr                     = 2,
        -- A window on a workspace Hyprland is not displaying stops receiving
        -- frame callbacks, so a game left on one blocks in its buffer swap
        -- and stops running at all; the render_unfocused rules below opt a
        -- window back into callbacks, and this is the rate they arrive at.
        -- 15 fps keeps a preview alive, not a game's simulation fed.
        render_unfocused_fps = 60,
    },
    ecosystem = {
        no_update_news = true,
    },
})

-- Applications
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))

-- Windows
hl.bind(mainMod .. " + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "0" }))
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen({ mode = "1" }))
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + ALT + P", hl.dsp.window.pin())
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.layout("allfloat"))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.resize({ x = 100, y = 0 }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.resize({ x = -100, y = 0 }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.resize({ x = 0, y = 100 }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.resize({ x = 0, y = -100 }))
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ out_of_group = true }))
hl.bind(mainMod .. " + K", hl.dsp.layout("swapsplit"))
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.swap({ direction = "down" }))

-- Actions
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprshot -m output"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("hyprshot -m window"))

-- Video twins of the screenshot binds above: same P/S/W letters, plus CTRL.
-- Each toggles; audio moves to A because SHIFT+S is the region video itself.
hl.bind(mainMod .. " + CTRL + SHIFT + P", hl.dsp.exec_cmd("screenrecord output"))
hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("screenrecord region"))
hl.bind(mainMod .. " + CTRL + SHIFT + W", hl.dsp.exec_cmd("screenrecord window"))
hl.bind(mainMod .. " + CTRL + SHIFT + A", hl.dsp.exec_cmd("screenrecord region --audio"))

hl.bind(mainMod .. " + CTRL + Return", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("hyprshade toggle blue-light-filter"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("hyprctl dispatch dpms toggle"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Workspaces
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

hl.bind(mainMod .. " + SHIFT + CTRL + 1", hl.dsp.window.move({ workspace = 1, follow = false }))
hl.bind(mainMod .. " + SHIFT + CTRL + 2", hl.dsp.window.move({ workspace = 2, follow = false }))
hl.bind(mainMod .. " + SHIFT + CTRL + 3", hl.dsp.window.move({ workspace = 3, follow = false }))
hl.bind(mainMod .. " + SHIFT + CTRL + 4", hl.dsp.window.move({ workspace = 4, follow = false }))
hl.bind(mainMod .. " + SHIFT + CTRL + 5", hl.dsp.window.move({ workspace = 5, follow = false }))
hl.bind(mainMod .. " + SHIFT + CTRL + 6", hl.dsp.window.move({ workspace = 6, follow = false }))
hl.bind(mainMod .. " + SHIFT + CTRL + 7", hl.dsp.window.move({ workspace = 7, follow = false }))
hl.bind(mainMod .. " + SHIFT + CTRL + 8", hl.dsp.window.move({ workspace = 8, follow = false }))
hl.bind(mainMod .. " + SHIFT + CTRL + 9", hl.dsp.window.move({ workspace = 9, follow = false }))
hl.bind(mainMod .. " + SHIFT + CTRL + 0", hl.dsp.window.move({ workspace = 10, follow = false }))

hl.bind(mainMod .. " + Tab",        hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + down",       hl.dsp.focus({ workspace = "empty" }))

-- Move focus
hl.bind("ALT + H", hl.dsp.focus({ direction = "left" }))
hl.bind("ALT + L", hl.dsp.focus({ direction = "right" }))
hl.bind("ALT + K", hl.dsp.focus({ direction = "up" }))
hl.bind("ALT + J", hl.dsp.focus({ direction = "down" }))

-- Alt-Tab
hl.bind("ALT + Tab", hl.dsp.layout("cyclenext"), { repeating = true })
hl.bind("ALT + Tab", hl.dsp.window.alter_zorder({ mode = "top" }), { repeating = true })

-- Mouse binds
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume and brightness (repeat + locked)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

-- Media controls (locked)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Layer rules
hl.layer_rule({ name = "no-anim-launcher",  match = { namespace = "launcher" },  no_anim = true })
hl.layer_rule({ name = "no-anim-selection", match = { namespace = "selection" }, no_anim = true })

-- Window rules
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name  = "no-focus-xwayland-empty",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
hl.window_rule({ name = "float-jetbrains-windows", match = { class = "^(jetbrains-.*)", title = "^(win.*)" }, float = true })
hl.window_rule({ name = "jetbrains-fade-no-focus", match = { class = "^(jetbrains-.*)" }, no_initial_focus = true, opacity = "0.9 0.9" })
hl.window_rule({ name = "opaque-code", match = { class = "^(cursor|Cursor|code-url-handler|Code|electron)$" }, opaque = true })
hl.window_rule({ name = "no-blur-code", match = { class = "^(cursor|Cursor|code-url-handler|Code|electron)$" }, no_blur = true })
hl.window_rule({ name = "steam-apps-empty-workspace", match = { class = "^(steam_app_[0-9]+)$" }, workspace = "empty" })
hl.window_rule({ name = "steam-apps-fullscreen", match = { class = "^(steam_app_[0-9]+)$" }, fullscreen = true })
hl.window_rule({ name = "steam-apps-render-unfocused", match = { class = "^(steam_app_[0-9]+)$" }, render_unfocused = true })
-- Games nested in gamescope surface as class gamescope, not steam_app_*;
-- float at the nested resolution so screen capture gets the bare 16:9 frame.
hl.window_rule({ name = "gamescope-empty-workspace", match = { class = "^(gamescope)$" }, workspace = "empty" })
hl.window_rule({ name = "gamescope-float-centered", match = { class = "^(gamescope)$" }, float = true, size = "2560 1440", center = true })
hl.window_rule({ name = "gamescope-render-unfocused", match = { class = "^(gamescope)$" }, render_unfocused = true })
          '';
        };
      };

      # Create screenshot and recording directories
      home.file."Screenshots/.keep".text = "";
      home.file."Recordings/.keep".text = "";
    };
}
