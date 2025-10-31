{ config, pkgs, ... }: {
  programs.bash.initExtra = ''
    # Clean up stale oh-my-posh cache on NixOS upgrades cine they may contain references to old store paths
    if command -v oh-my-posh &>/dev/null; then
      # Remove cache files older than 7 days to prevent stale path issues
      find ~/.cache/oh-my-posh/ -name "*.omp.cache" -type f -mtime +7 -delete 2>/dev/null || true
      eval "$(oh-my-posh init bash --config $HOME/.config/ohmyposh/EDM115-newline.omp.json)"
    fi
  '';
}