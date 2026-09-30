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
