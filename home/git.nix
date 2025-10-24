{ config, pkgs, ... }: {
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
}