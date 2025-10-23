{ pkgs, ... }: {
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
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
