{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    claude-code
    cmake
    codex
    crush
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
    python3
    qwen-code
    redis
  ];
  
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
