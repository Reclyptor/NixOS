{ config, pkgs, ... }: {
  programs.bash.initExtra = ''
    if [[ $(tty) == *"pts"* ]]; then
      if command -v fastfetch &>/dev/null; then
        fastfetch --config examples/13
      fi
    else
      echo
      if [ -f /bin/hyprctl ]; then
        echo "Start Hyprland with command Hyprland"
      fi
    fi
    
    for f in ~/.config/bashrc/*; do 
      if [ ! -d $f ]; then
        c=$(echo $f | sed -e "s=.config/bashrc=.config/bashrc/custom=")
        [[ -f $c ]] && source $c || source $f
      fi
    done
  '';
}