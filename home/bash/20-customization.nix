{ config, pkgs, ... }: {
  programs.bash.initExtra = ''
    if command -v oh-my-posh &>/dev/null; then
      eval "$(oh-my-posh init bash --config $HOME/.config/ohmyposh/EDM115-newline.omp.json)"
    fi
  '';
}