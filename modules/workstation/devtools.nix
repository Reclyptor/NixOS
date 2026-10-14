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
      duckdb
      gallery-dl
      gcc
      gh
      github-copilot-cli
      go
      gum
      jdk
      mongosh
      mysql84
      postgresql
      natscli
      nodejs
      opencode
      prime-agent
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
