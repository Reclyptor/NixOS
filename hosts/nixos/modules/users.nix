{ config, pkgs, ... }: {
  users.users.reclyptor = {
    isNormalUser = true;
    shell = pkgs.bash;
    description = "Reclyptor";
    extraGroups = [ "reclyptor" "networkmanager" "wheel" "docker" "cdrom" "i2c" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO+1lRwgeyXwQATyVsXL+zXsnkZr5UHqeGGPn+G97yH1"
    ];
    packages = with pkgs; [ ];
  };
}
