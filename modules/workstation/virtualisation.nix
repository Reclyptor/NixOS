_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      docker-compose
    ];

    virtualisation.docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
      # `docker system prune -f` weekly with no filter flags: every stopped
      # container, dangling image, unused network and build-cache layer is
      # reclaimed. Deliberate housekeeping on a machine whose docker use is
      # mostly transient build cache, but know the price: a container left
      # stopped does not survive the week. Volumes are never pruned (no
      # --volumes).
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };
}
