_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      aldo
      aseprite
      audacity
      brave
      code-cursor
      google-chrome
      discord
      discordx
      element-desktop
      firefox
      imv
      inkscape
      # Browses and installs the itch.io library. Native Linux builds it runs
      # itself; for a Windows-only title its own bundled Wine is the weak part on
      # NixOS, so run those through `jpgame` (jpgames.nix) instead.
      itch
      krita
      mkvtoolnix
      morse-linux
      mpv
      mpvx
      obsidian
      prismlauncher
      qbittorrent
      signal-desktop
      spotify
      unixcw
      vlc
      vintagestory
      whipper
      zed-editor
      zen-browser
    ];
  };
}
