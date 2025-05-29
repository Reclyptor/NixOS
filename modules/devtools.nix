{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    gcc
    go
    jdk
    mongosh
    mysql84
    nodejs
    python3
  ];
}
