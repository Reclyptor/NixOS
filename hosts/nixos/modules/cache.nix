{ config, pkgs, ... }: {
  # Configure binary caches to avoid building packages locally
  nix.settings = {
    # Trusted users who can add substituters
    trusted-users = [ "root" "@wheel" ];
    
    # Binary cache substituters (ordered by priority)
    substituters = [
      "https://cache.nixos.org"           # Default NixOS cache
      "https://hyprland.cachix.org"       # Hyprland and related packages
      "https://cuda-maintainers.cachix.org" # CUDA packages
      "https://nix-community.cachix.org"  # Nix community packages
      "https://numtide.cachix.org"        # direnv, devenv, and dev tools
      "https://nixpkgs-wayland.cachix.org" # Wayland-related packages
      "https://nixpkgs-unfree.cachix.org" # NixOS unstable and frequently updated packages
      "https://crane.cachix.org"          # Rust projects and toolchains
      "https://ai.cachix.org"             # Machine learning and scientific computing
    ];
    
    # Public keys for the substituters
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "crane.cachix.org-1:8Sw/sLJFIXWWlcSU8VKaYiC6M8kl2ZrBn6pA5J6M6yg="
      "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
    ];
    
    # Fallback to building if cache is unavailable
    fallback = true;
    
    # Enable parallel building
    max-jobs = "auto";
    cores = 0;  # Use all available cores
  };
}

