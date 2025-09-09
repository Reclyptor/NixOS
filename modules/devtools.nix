{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    cmake
    gcc
    go
    jdk
    mongosh
    mysql84
    nodejs
    python3
  ];
}
