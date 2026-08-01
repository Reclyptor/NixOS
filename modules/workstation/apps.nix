{ ... }: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      aldo
      aseprite
      audacity
      brave
      code-cursor
      google-chrome
      hytale
      discord
      discordx
      element-desktop
      firefox
      imv
      inkscape
      krita
      makemkv
      mkvtoolnix
      morse-linux
      mpv
      mpvx
      obs-studio
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
