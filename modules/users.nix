{ config, pkgs, ... }: {
  users.users.reclyptor = {
    isNormalUser = true;
    description = "Reclyptor";
    shell = pkgs.bash;
    extraGroups = [ "reclyptor" "networkmanager" "wheel" "docker" "cdrom" ];
    packages = with pkgs; [ ];
  };
}
