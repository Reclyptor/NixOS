{ config, pkgs, ... }: {
  system.stateVersion = "25.05";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports = [
    ./hardware-configuration.nix
    ../../modules/users.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelModules = [ "iscsi_tcp" "amdgpu" "kvm-amd" ];
  boot.kernelParams = [ "amdgpu.dc=1" "amdgpu.dpm=1" ];
  boot.supportedFilesystems = [ "nfs" ];

  networking.hostName = "fluxeon";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = { layout = "us"; variant = ""; };

  nixpkgs.config.allowUnfree = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      mesa.drivers
      vaapiVdpau
      libvdpau-va-gl
      rocmPackages.clr.icd
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      mesa.drivers
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    ROC_ENABLE_PRE_VEGA = "1";
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST = "gpl";
  };

  environment.systemPackages = with pkgs; [
    git
    kubectl
    neovim
    openiscsi
    wget
    pciutils
    libva-utils
    vulkan-tools
    clinfo
    ffmpeg-full
    radeontop
    mesa-demos
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
    secrets."k3s/token" = { };
  };

  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://192.168.1.10:6443";
    tokenFile = config.sops.secrets."k3s/token".path;
    extraFlags = [ ];
  };

  networking.firewall = {
    allowedTCPPorts = [ 10250 3260 ];
    allowedUDPPorts = [ 8472 ];
  };

  services.openssh.enable = true;

  services.openiscsi.enable = true;
  services.openiscsi.name = "iqn.2005-10.org.freenas.ctl";

  users.groups.video = {};
  users.groups.render = {};

  systemd.tmpfiles.rules = [
    "d /usr/sbin 0755 root root -"
    "L+ /usr/sbin/iscsiadm - - - - /run/current-system/sw/bin/iscsiadm"
    "d /sbin 0755 root root -"
    "L+ /sbin/iscsiadm - - - - /run/current-system/sw/bin/iscsiadm"
    "d /dev/dri 0755 root video -"
    "d /var/lib/plex-transcode 0755 root root -"
  ];

  systemd.services.k3s.after = [ "iscsid.service" ];
  systemd.services.k3s.requires = [ "iscsid.service" ];
}
