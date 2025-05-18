{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    docker
    gcc
    go
    jdk
    mongosh
    mysql84
    nodejs
  ];
}
