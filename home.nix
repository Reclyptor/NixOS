{ config, pkgs, ... }: {
  home.username = "reclyptor";
  home.homeDirectory = "/home/reclyptor";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Reclyptor";
      user.email = "5952751+Reclyptor@users.noreply.github.com";
      user.signingkey = "0A839138373B99EE";
      init.defaultBranch = "master";
      commit.gpgsign = false;
      gpg.program = "gpg";
      core.editor = "nvim";
      safe.directory = "/etc/nixos";
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      ls = "eza -a --icons=always";
      tree = "eza -a --tree --icons=always";
      vim = "nvim";
    };
    bashrcExtra = ''
      for f in ~/.config/bashrc/*; do 
        if [ ! -d $f ]; then
          c=$(echo $f | sed -e "s=.config/bashrc=.config/bashrc/custom=")
          [[ -f $c ]] && source $c || source $f
        fi
      done
    '';
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.home-manager.enable = true;
}
