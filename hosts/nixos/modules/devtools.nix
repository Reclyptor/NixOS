{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    claude-code
    cmake
    codex
    deno
    gcc
    gh
    go
    gum
    jdk
    mongosh
    mysql84
    postgresql
    natscli
    nodejs
    redis
  ];
  
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
