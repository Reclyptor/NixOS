_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      claude-code
      cmake
      codeburn
      codex
      crush
      deno
      dsh
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
      opencode
      python3
      qwen-code
      rcon-cli
      redis
    ];

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
