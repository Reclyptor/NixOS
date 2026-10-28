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
        #
        # One file per concern. Hyprland wraps require() so a runtime error
        # in a module is reported and the next module still loads, but inside
        # a module everything after the failing line is lost. Keeping binds,
        # rules and settings apart means a typo in one cannot take the others
        # down with it.
        configType = "lua";

        extraLuaFiles."00-settings".content = ''
          -- Monitor: ultrawide 5120x1440@240, regardless of connector naming
          hl.monitor({ output = "", mode = "5120x1440@240", position = "auto", scale = "1" })

          hl.config({ xwayland = { force_zero_scaling = true } })

          hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
          hl.env("XDG_SESSION_DESKTOP", "Hyprland")
          hl.env("XDG_SESSION_TYPE", "wayland")
          hl.env("HYPRSHOT_DIR", "${config.home.homeDirectory}/Screenshots")

          -- Autostart. hyprpaper is a systemd user service (see hyprpaper.nix) so that
          -- home-manager restarts it when its config changes; home-manager adds its own
          -- hyprland-session.target hook after these modules.
          hl.on("hyprland.start", function()
              hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11")
              hl.exec_cmd("nm-applet --indicator")
          end)

          hl.config({
              input = {
                  kb_layout  = "us",
                  kb_variant = "",
                  kb_model   = "",
                  kb_options = "",
                  kb_rules   = "",

                  repeat_delay = 200,
                  repeat_rate  = 25,

                  follow_mouse = 1,
                  sensitivity  = 0,

                  touchpad = {
                      natural_scroll = false,
                  },
              },

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

              animations = {
                  enabled = true,
              },

              dwindle = {
                  preserve_split = true,
              },

              master = {
                  new_status = "master",
              },

              misc = {
                  force_default_wallpaper = -1,
                  disable_hyprland_logo   = false,
                  vrr                     = 2,

                  -- A window on a workspace Hyprland is not displaying stops receiving
                  -- frame callbacks, so a game left on one blocks in its buffer swap and
                  -- stops running at all -- and because most engines drive networking
                  -- from the same loop, a multiplayer session reads that as a client
                  -- that has stopped answering and drops it. The render_unfocused rule
                  -- in 10-rules opts a window back into callbacks; this is the rate they
                  -- arrive at. The default of 15 is a budget for keeping a preview
                  -- alive, not for keeping a game's simulation fed -- nor for a video
                  -- being streamed to Discord, whose ceiling is also 60.
                  render_unfocused_fps = 60,
              },

              ecosystem = {
                  no_update_news = true,
              },
          })

          hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

          hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}   } })
          hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}   } })
          hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}      } })
          hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1.0} } })
          hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}    } })
          hl.curve("bounce",         { type = "bezier", points = { {0.34, 1.56}, {0.64, 1}   } })

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
        '';

        extraLuaFiles."10-rules".content = ''
          hl.layer_rule({ name = "no-anim-launcher",  match = { namespace = "launcher" },  no_anim = true })
          hl.layer_rule({ name = "no-anim-selection", match = { namespace = "selection" }, no_anim = true })

          hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
          hl.window_rule({
              name     = "no-focus-xwayland-empty",
              match    = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
              no_focus = true,
          })
          hl.window_rule({ name = "float-jetbrains-windows", match = { class = "^(jetbrains-.*)", title = "^(win.*)" }, float = true })
          hl.window_rule({ name = "jetbrains-no-initial-focus", match = { class = "^(jetbrains-.*)" }, no_initial_focus = true, opacity = "0.9 0.9" })
          hl.window_rule({ name = "opaque-code", match = { class = "^(cursor|Cursor|code-url-handler|Code|electron)$" }, opaque = true })
          hl.window_rule({ name = "no-blur-code", match = { class = "^(cursor|Cursor|code-url-handler|Code|electron)$" }, no_blur = true })

          hl.window_rule({ name = "steam-apps-empty-workspace",  match = { class = "^(steam_app_[0-9]+)$" }, workspace = "empty" })
          hl.window_rule({ name = "steam-apps-fullscreen",       match = { class = "^(steam_app_[0-9]+)$" }, fullscreen = true })
          hl.window_rule({ name = "steam-apps-render-unfocused", match = { class = "^(steam_app_[0-9]+)$" }, render_unfocused = true })

          -- Games nested in gamescope surface as class gamescope, not steam_app_*;
          -- float at the nested resolution so screen capture gets the bare 16:9 frame.
          hl.window_rule({ name = "gamescope-empty-workspace",  match = { class = "^(gamescope)$" }, workspace = "empty" })
          hl.window_rule({ name = "gamescope-float-centered",   match = { class = "^(gamescope)$" }, float = true, size = "2560 1440", center = true })
          hl.window_rule({ name = "gamescope-render-unfocused", match = { class = "^(gamescope)$" }, render_unfocused = true })

          -- mpvx (XWayland mpv) is what gets streamed to Discord while a game holds
          -- another workspace. Without callbacks XWayland's Present stalls mpv's swaps,
          -- and Discord's X11 capturer streams the resulting bursts as stutter.
          -- Native-Wayland mpv is not capturable by discordx, so it is left out.
          hl.window_rule({ name = "mpvx-render-unfocused", match = { class = "^(mpv)$", xwayland = true }, render_unfocused = true })
        '';

        extraLuaFiles."20-binds".content = ''
          local terminal    = "kitty"
          local fileManager = "kitty yazi"
          local browser     = "zen-beta"
          local menu        = "pkill fuzzel || fuzzel"
          local mainMod     = "SUPER"

          -- Applications
          hl.bind(mainMod .. " + Return",        hl.dsp.exec_cmd(terminal))
          hl.bind(mainMod .. " + B",             hl.dsp.exec_cmd(browser))
          hl.bind(mainMod .. " + E",             hl.dsp.exec_cmd(fileManager))
          hl.bind(mainMod .. " + CTRL + Return", hl.dsp.exec_cmd(menu))

          -- Windows. close() asks the client to close (hyprlang killactive); kill() is
          -- SIGKILL (forcekillactive), which on an Xwayland client like Steam takes
          -- down its whole process and Steam respawns its window.
          hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
          hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("hyprctl activewindow | grep pid | tr -d 'pid:' | xargs kill"))
          hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "0" }))
          hl.bind(mainMod .. " + M",         hl.dsp.window.fullscreen({ mode = "1" }))
          hl.bind(mainMod .. " + T",         hl.dsp.window.float({ action = "toggle" }))
          hl.bind(mainMod .. " + ALT + P",   hl.dsp.window.pin())
          hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())
          hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))
          hl.bind(mainMod .. " + K",         hl.dsp.layout("swapsplit"))
          hl.bind(mainMod .. " + G",         hl.dsp.group.toggle())
          hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ out_of_group = true }))

          -- Without relative = true the numbers are an absolute size, and a 0 axis is
          -- rejected outright.
          hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.resize({ x = 100,  y = 0,    relative = true }))
          hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.resize({ x = -100, y = 0,    relative = true }))
          hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.resize({ x = 0,    y = 100,  relative = true }))
          hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.resize({ x = 0,    y = -100, relative = true }))

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
          -- Each toggles -- press to pick and record, press again to stop. Audio moves
          -- to A because SHIFT+S is the region video itself.
          hl.bind(mainMod .. " + CTRL + SHIFT + P", hl.dsp.exec_cmd("screenrecord output"))
          hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("screenrecord region"))
          hl.bind(mainMod .. " + CTRL + SHIFT + W", hl.dsp.exec_cmd("screenrecord window"))
          hl.bind(mainMod .. " + CTRL + SHIFT + A", hl.dsp.exec_cmd("screenrecord region --audio"))

          hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("hyprshade toggle blue-light-filter"))
          hl.bind(mainMod .. " + D", hl.dsp.dpms({ action = "toggle" }))
          hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

          -- Workspaces: SUPER+N to switch, +SHIFT to take the window along, +SHIFT+CTRL
          -- to send it without following. Key 0 is workspace 10.
          for i = 1, 10 do
              local key = tostring(i % 10)
              hl.bind(mainMod .. " + " .. key,                hl.dsp.focus({ workspace = i }))
              hl.bind(mainMod .. " + SHIFT + " .. key,        hl.dsp.window.move({ workspace = i }))
              hl.bind(mainMod .. " + SHIFT + CTRL + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
          end

          hl.bind(mainMod .. " + Tab",         hl.dsp.focus({ workspace = "m+1" }))
          hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))
          hl.bind(mainMod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }))
          hl.bind(mainMod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }))
          hl.bind(mainMod .. " + down",        hl.dsp.focus({ workspace = "empty" }))

          hl.bind("ALT + H", hl.dsp.focus({ direction = "left" }))
          hl.bind("ALT + L", hl.dsp.focus({ direction = "right" }))
          hl.bind("ALT + K", hl.dsp.focus({ direction = "up" }))
          hl.bind("ALT + J", hl.dsp.focus({ direction = "down" }))

          -- Alt-Tab: both binds fire on the same press, in order.
          hl.bind("ALT + Tab", hl.dsp.window.cycle_next(),                  { repeating = true })
          hl.bind("ALT + Tab", hl.dsp.window.alter_zorder({ mode = "top" }), { repeating = true })

          -- Mouse binds are inferred from the mouse: key.
          hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
          hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

          hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),     { locked = true, repeating = true })
          hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),     { locked = true, repeating = true })
          hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),    { locked = true, repeating = true })
          hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),  { locked = true, repeating = true })
          hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl s 10%+"),                         { locked = true, repeating = true })
          hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"),                         { locked = true, repeating = true })

          hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
          hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
          hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
          hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
        '';
      };

      # Create screenshot and recording directories
      home.file."Screenshots/.keep".text = "";
      home.file."Recordings/.keep".text = "";
    };
}
