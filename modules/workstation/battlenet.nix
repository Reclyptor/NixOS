_: {
  # World of Warcraft ships through Battle.net, not Steam, so none of steam.nix
  # reaches it: the launch-option injector walks localconfig.vdf and only knows
  # about appmanifest_* games, extraCompatPackages publishes Proton to a search
  # path Steam never consults for a process it did not start, and the Hyprland
  # windowrules key on ^(steam_app_[0-9]+)$, which a Battle.net window is not.
  # This is therefore a parallel launch path rather than an extension of that
  # one. What it does reuse is GameMode and the 32-bit graphics stack.
  flake.modules.nixos.workstation =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Battle.net owns its own dataset. A Wine prefix plus a 65-69 GB install is
      # exactly the churn that should not land in /home's snapshots (rpool is at
      # 1.1T of 1.8T), and Battle.net refuses to run from NTFS — ZFS is fine.
      # Created out of band with `zfs create npool/data/battlenet`, matching how
      # npool/data/steam was made: this repo declares pools via
      # boot.zfs.extraPools, never datasets.
      root = "/data/nvme/battlenet";

      # The Proton build, pinned by flake.lock rather than left to umu's runtime
      # download. Left to itself umu fetches UMU-Proton over the network on first
      # run, which makes the effective build a function of when you happened to
      # start it. That is not hypothetical here: GE-Proton10-34 could not create
      # a Vulkan swapchain on this GPU while other builds could, and a silently
      # moving Proton is how that becomes a mystery instead of a diff.
      #
      # Re-point this one binding to change builds.
      protonPackage = pkgs.proton-ge-bin;

      # Where Battle.net puts itself inside the prefix. Its installer picks this,
      # not us; it is spelled out so the wrappers do not have to go looking.
      launcher = "${root}/prefix/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe";

      # gamemoderun has to come from the configured package: gamemode.nix
      # rewrites it to preload libgamemode by absolute path, and pkgs.gamemode
      # here would be the unpatched upstream script, which would load nothing and
      # fail silently.
      gamemoderun = "${config.programs.gamemode.package}/bin/gamemoderun";

      # GAMEID and STORE select a protonfix from the umu-database. Checked
      # 2026-09-30: that database carries no Battle.net or World of Warcraft row
      # (schema TITLE,STORE,CODENAME,UMU_ID,…), so there is no fix to select and
      # the documented defaults are the honest values rather than a guess.
      # Revisit if an entry lands upstream.
      commonEnv = ''
        export WINEPREFIX=${root}/prefix
        export GAMEID=umu-default
        export STORE=none

        # .steamcompattool, not the default output. proton-ge-bin's $out is a
        # deliberate stub — a text file reading "should not be installed into
        # environments" — so pointing PROTONPATH at the package itself hands umu
        # a regular file where it expects a Proton tree. umu resolves it with
        # strict=True, which a file satisfies, so the failure would surface later
        # and nowhere near its cause.
        export PROTONPATH=${protonPackage.steamcompattool}

        # Battle.net's launcher is a Chromium shell that renders blank or white
        # under Wine without this. Two independent Battle.net-on-Proton projects
        # set it for exactly that symptom, and it is inert when the symptom is
        # absent.
        export WINE_SIMULATE_WRITECOPY=1

        # Keep the shader caches next to the game. Left at their defaults they
        # accumulate without bound under ~/.cache, on the pool with the least
        # room to spare. Both DXVK spellings are set: 3.0 renamed the variable to
        # DXVK_SHADER_CACHE_PATH, and GE-Proton builds straddle that change, so
        # setting only one silently does nothing on half of them.
        export DXVK_STATE_CACHE_PATH=${root}/cache
        export DXVK_SHADER_CACHE_PATH=${root}/cache
        export __GL_SHADER_DISK_CACHE=1
        export __GL_SHADER_DISK_CACHE_PATH=${root}/cache
        export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

        # PROTON_ENABLE_WAYLAND is deliberately absent. winewayland.drv makes the
        # swapchain create cleanly on this machine and Hyprland then composites
        # the window solid black; XWayland is the path that actually renders.
        #
        # So is any further Proton tuning: the community reports on WoW Forever
        # are consistent that a bare invocation works where extra options crash,
        # so anything added here needs evidence, not optimism.
        #
        # Held back deliberately, each a documented remedy for a symptom we have
        # not seen. Reach for them only against an observed failure:
        #   WINEDLLOVERRIDES=locationapi=d   launcher fails to start
        #   --in-process-gpu                 (launcher arg) white launcher window
        #   PROTON_ENABLE_NVAPI=1            Reflex; unmeasured for this game
        #   PROTON_ENABLE_WAYLAND=1          exposes ultrawide modes that XWayland
        #                                    hides — but see the note above, it
        #                                    renders black on this compositor
      '';

      # One wrapper per thing you would actually double-click. `args` are passed
      # to the Battle.net launcher, which interprets --game= itself.
      launch =
        {
          name,
          args ? [ ],
          hud ? false,
        }:
        pkgs.writeShellScriptBin name ''
          set -euo pipefail
          ${commonEnv}
          ${lib.optionalString hud "export MANGOHUD=1"}
          exec ${gamemoderun} ${pkgs.umu-launcher}/bin/umu-run \
            "${launcher}" ${lib.escapeShellArgs args} "$@"
        '';

      # The beta's product code. This changes when Forever leaves beta on
      # 2026-11-04 — it is isolated here so that is a one-line edit.
      wowProduct = "wow_classic_beta";

      battlenet = launch { name = "battlenet"; };
      wow-forever = launch {
        name = "wow-forever";
        args = [ "--game=${wowProduct}" ];
      };
      wow-forever-hud = launch {
        name = "wow-forever-hud";
        args = [ "--game=${wowProduct}" ];
        hud = true;
      };

      desktopItem =
        {
          name,
          desktopName,
          exec,
          comment,
        }:
        pkgs.makeDesktopItem {
          inherit name desktopName comment;
          exec = "${exec}/bin/${name}";
          icon = "applications-games";
          categories = [
            "Game"
            "RolePlaying"
          ];
          terminal = false;
        };
    in
    {
      environment.systemPackages = [
        battlenet
        wow-forever
        wow-forever-hud

        (desktopItem {
          name = "battlenet";
          desktopName = "Battle.net";
          exec = battlenet;
          comment = "Blizzard's game launcher, under Proton";
        })
        (desktopItem {
          name = "wow-forever";
          desktopName = "World of Warcraft: Forever";
          exec = wow-forever;
          comment = "Launch WoW: Forever through Battle.net";
        })
      ]
      ++ (with pkgs; [
        umu-launcher

        # Prefix surgery. Battle.net's documented failure modes (the update loop,
        # a greyed-out install button) are fixed inside the prefix, and doing
        # that without this means doing it by hand.
        #
        # protontricks is deliberately not here despite being the obvious
        # neighbour: it discovers prefixes through Steam's appmanifests, and this
        # prefix belongs to umu, not Steam, so it cannot see it. If it is ever
        # wanted for the actual Steam library, the right lever is
        # programs.steam.protontricks.enable in steam.nix — that one passes
        # extraCompatPaths through, which a bare package in systemPackages does
        # not.
        winetricks

        # vkcube and vulkaninfo. These are the diagnostic that separates "Proton
        # is broken" from "the driver is broken" — running vkcube on both the
        # XWayland and Wayland paths is what collapsed a previous multi-hour
        # white-screen hunt on this machine into one test. They belong here
        # before something breaks, not after.
        vulkan-tools

        # Addon manager. Runs natively — unlike CurseForge's own app, which would
        # need a Wine prefix of its own.
        #
        # instawow would be the nicer answer (a CLI, no Electron), but it does
        # not build against this nixpkgs pin: its aiohttp-client-cache 0.14.3
        # dependency fails to import against the packaged aiohttp 3.14.3
        # (ClientResponse.__init__() missing the stream_writer argument). That is
        # a real API mismatch rather than a flaky test, so forcing it through
        # with doCheck = false would only move the failure to runtime. Revisit
        # when nixpkgs catches up.
        wowup-cf
      ]);

      # Battle.net's login and launcher crawl unless the machine's own hostname
      # resolves to a loopback address. It did not: /etc/hosts carried the
      # NixOS-default `127.0.0.2 nixos`, but `getent hosts nixos` answered with
      # the IPv6 link-local address NetworkManager publishes, which is what
      # Battle.net actually got.
      networking.hosts."127.0.0.1" = [ config.networking.hostName ];
    };
}
