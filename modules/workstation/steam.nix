_: {
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    let
      # Steam has no global launch-option default, so the same two flags have to
      # be written into every game individually, and a newly installed game
      # arrives with the field blank. Rather than fixing that by hand each time,
      # this writes both rules into localconfig.vdf:
      #
      #   * `gamemoderun %command%` everywhere it is blank, so games actually
      #     run under GameMode (see gamemode.nix for why gamemoderun needed
      #     patching before that meant anything inside Steam's container).
      #   * `SDL_VIDEODRIVER=x11` on native Linux games, which otherwise die on
      #     this machine's Hyprland/NVIDIA pair the moment SDL opens a Wayland
      #     window: the driver and the game both attach a syncobj to the
      #     surface, Hyprland rejects the second with "Surface already has a
      #     syncobj attached" and drops the connection, which the game reads as
      #     a quit request. Proton games are left alone — they reach the display
      #     through wine, not SDL.
      #
      # Both rules are idempotent and neither overwrites an existing option: a
      # game that already carries flags only ever gains the SDL variable, and
      # only when it does not already set one.
      #
      # Run by hand with Steam closed, which the script enforces. Steam holds
      # localconfig.vdf open and rewrites it wholesale on exit, so anything
      # written underneath a running client is silently discarded.
      launchOptions = pkgs.writers.writePython3Bin "steam-launch-options" { flakeIgnore = [ "E501" ]; } ''
        import argparse
        import os
        import re
        import shutil
        import sys
        import time

        STEAM_ROOT = os.path.expanduser("~/.local/share/Steam")
        GAMEMODE = "gamemoderun %command%"
        SDL_X11 = "SDL_VIDEODRIVER=x11"

        # Soundtracks, Proton builds and the runtimes live in the same app list as
        # games and own no executable worth inspecting.
        NOT_A_GAME = re.compile(r"proton|steam linux runtime|steamworks common|soundtrack", re.I)

        KEY_LINE = re.compile(r'^(\s*)"([^"]+)"\s*$')
        FIELD_LINE = re.compile(r'^(\s*)"([^"]+)"\s+"(.*)"\s*$')


        def steam_is_running():
            for pid in os.listdir("/proc"):
                if not pid.isdigit():
                    continue
                try:
                    with open("/proc/" + pid + "/comm", encoding="utf-8") as handle:
                        if handle.read().strip() == "steam":
                            return True
                except OSError:
                    continue
            return False


        def library_paths():
            paths = [STEAM_ROOT]
            index = os.path.join(STEAM_ROOT, "steamapps", "libraryfolders.vdf")
            try:
                with open(index, encoding="utf-8", errors="replace") as handle:
                    paths += re.findall(r'"path"\s+"([^"]+)"', handle.read())
            except OSError:
                pass
            return list(dict.fromkeys(paths))


        def installed_games():
            games = {}
            for library in library_paths():
                steamapps = os.path.join(library, "steamapps")
                try:
                    entries = os.listdir(steamapps)
                except OSError:
                    continue
                for entry in entries:
                    if not entry.startswith("appmanifest_"):
                        continue
                    try:
                        with open(os.path.join(steamapps, entry), encoding="utf-8", errors="replace") as handle:
                            manifest = handle.read()
                    except OSError:
                        continue
                    appid = re.search(r'"appid"\s+"(\d+)"', manifest)
                    name = re.search(r'"name"\s+"([^"]*)"', manifest)
                    installdir = re.search(r'"installdir"\s+"([^"]*)"', manifest)
                    if not (appid and installdir):
                        continue
                    title = name.group(1) if name else appid.group(1)
                    if NOT_A_GAME.search(title):
                        continue
                    games[appid.group(1)] = (title, os.path.join(steamapps, "common", installdir.group(1)))
            return games


        def is_native(path):
            """True when the install tree holds a Linux executable of its own.

            Depth is capped because a Proton game can carry a Linux binary deep in
            a vendored toolchain, while a native game always puts one near the top.
            """
            if not os.path.isdir(path):
                return False
            for root, dirs, files in os.walk(path):
                if root[len(path):].count(os.sep) >= 2:
                    dirs[:] = []
                for name in files:
                    if name.endswith(".so") or ".so." in name:
                        continue
                    candidate = os.path.join(root, name)
                    if not os.access(candidate, os.X_OK):
                        continue
                    try:
                        with open(candidate, "rb") as handle:
                            if handle.read(4) == b"\x7fELF":
                                return True
                    except OSError:
                        continue
            return False


        def wanted(current, native):
            options = current.strip() or GAMEMODE
            if native and "SDL_VIDEODRIVER" not in options:
                options = SDL_X11 + " " + options
            return options


        def rewrite(path, natives, titles, dry_run):
            with open(path, encoding="utf-8") as handle:
                lines = handle.read().split("\n")

            stack = []
            pending = None
            entry = None
            edits = []
            inserts = []

            for index, line in enumerate(lines):
                stripped = line.strip()

                key = KEY_LINE.match(line)
                if key:
                    pending = (key.group(2), key.group(1))
                    continue

                if stripped == "{":
                    stack.append(pending[0] if pending else None)
                    in_app_list = len(stack) >= 2 and stack[-2] == "apps" and "Steam" in stack
                    if entry is None and in_app_list and (stack[-1] or "").isdigit():
                        entry = {
                            "appid": stack[-1],
                            "depth": len(stack),
                            "line": None,
                            "value": "",
                            "insert": index + 1,
                            "indent": pending[1] + "\t",
                        }
                    pending = None
                    continue

                if stripped == "}":
                    if entry is not None and len(stack) == entry["depth"]:
                        target = wanted(entry["value"], entry["appid"] in natives)
                        if target != entry["value"]:
                            field = entry["indent"] + '"LaunchOptions"\t\t"' + target + '"'
                            if entry["line"] is None:
                                inserts.append((entry["insert"], field))
                            else:
                                lines[entry["line"]] = field
                            edits.append((entry["appid"], entry["value"], target))
                        entry = None
                    if stack:
                        stack.pop()
                    continue

                field = FIELD_LINE.match(line)
                in_this_entry = entry is not None and len(stack) == entry["depth"]
                if field and in_this_entry and field.group(2) == "LaunchOptions":
                    entry["line"] = index
                    entry["value"] = field.group(3)

            for appid, before, after in edits:
                label = titles.get(appid, appid)
                print("  " + label + " [" + appid + "]")
                print("      " + (before or "<blank>") + "  ->  " + after)

            if not edits:
                print("Nothing to change; every entry already carries the right options.")
                return 0

            if dry_run:
                print("\n" + str(len(edits)) + " entries would change (dry run; nothing written).")
                return 0

            backup = path + ".bak-" + str(int(time.time()))
            shutil.copy2(path, backup)
            for index, text in sorted(inserts, key=lambda item: -item[0]):
                lines.insert(index, text)
            with open(path, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines))
            print("\n" + str(len(edits)) + " entries updated. Backup: " + backup)
            return 0


        def main():
            parser = argparse.ArgumentParser(description="Apply this machine's Steam launch options to every game.")
            parser.add_argument("--dry-run", action="store_true", help="report what would change and write nothing")
            args = parser.parse_args()

            if steam_is_running():
                sys.exit("Steam is running; it would overwrite these edits on exit. Close it and try again.")

            configs = []
            userdata = os.path.join(STEAM_ROOT, "userdata")
            try:
                for user in os.listdir(userdata):
                    candidate = os.path.join(userdata, user, "config", "localconfig.vdf")
                    if os.path.isfile(candidate):
                        configs.append(candidate)
            except OSError:
                pass
            if not configs:
                sys.exit("No localconfig.vdf found under " + userdata)

            games = installed_games()
            natives = {appid for appid, (_, path) in games.items() if is_native(path)}
            titles = {appid: title for appid, (title, _) in games.items()}
            print(str(len(natives)) + " native Linux games out of " + str(len(games)) + " installed.\n")

            status = 0
            for config in configs:
                print(config)
                status |= rewrite(config, natives, titles, args.dry_run)
            return status


        if __name__ == "__main__":
            sys.exit(main())
      '';
    in
    {
      # steam is deliberately absent: programs.steam below installs its own
      # package and steam-run. Adding bare pkgs.steam here collides with it on
      # bin/steam and the bare one wins, which costs the FHS environment
      # everything programs.steam.fontPackages folds in from fonts.packages. The
      # Steam Linux Runtime container then exports that fontless environment to
      # steamwebhelper and the client UI draws every CJK codepoint as tofu.
      environment.systemPackages = with pkgs; [
        launchOptions
        mangohud
        protonup-qt
      ];

      programs.steam = {
        enable = true;
        gamescopeSession.enable = false;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
      };
    };
}
