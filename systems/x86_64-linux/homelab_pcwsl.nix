{
  modulesPath,
  pkgs,
  config,
  inputs,
  lib,
  sensitive,
  ...
}: let
  hostName = "homelab_pcwsl";
  # secrets = config.sops.secrets;
  # wg = import ../common/wg.nix {inherit lib sensitive;};
  # sniproxy-domains = import ../common/sniproxy-domains.nix;
in {
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ../common
    ../common/wsl-kernel.nix
  ];
  wsl = {
    enable = true;
    defaultUser = "hey";
  };

  # sops = {
  #   defaultSopsFile = ../../secrets/homelab_box.yaml;
  #   age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  #   secrets = {
  #     "frpc.env" = {};
  #     "wireguard.key" = {
  #       owner = "systemd-network";
  #     };
  #   };
  # };

  # users.extraUsers.hey.extraGroups = ["docker"];
  environment.systemPackages = with pkgs; [
    # wireguard-tools # for vscode remote

    # frp

    ffmpeg
    stash
    vips
    patchelf
    n-m3u8dl-re

    # radeontop
  ];

  # virtualisation.docker = {
  #   enable = true;
  # };

  # installed.monitoring = {
  #   vmagent = true;
  #   vmagent-remote = wg.configs.homelab_txcdhub.address;
  #   node_exporter = true;

  #   nginx = true;
  # };
  # services.postgresql.enable = true;
  # services.nginx.enable = true;
  # services.avahi.enable = true;
  # services.avahi.publish.enable = true;
  # services.avahi.openFirewall = true;
  # services.avahi.publish.userServices = true;

  # We also have enabled mDNS since we're already using Avahi anyways.
  # services.avahi.nssmdns4 = true;
  # services.avahi.nssmdns6 = true;

  # services.mimic = {
  #   enable = true;
  #   interfaces.eth0 = {
  #     enable = true;
  #     filters = wg.mimic-filters.${hostName};
  #     xdpMode = "skb";
  #   };
  # };
  # services.stash = {
  #   enable = true;
  #   settings = {
  #     stash = [
  #       {
  #         Path = "/mnt/store/videos/70726f6e";
  #         ExcludeImage = true;
  #       }
  #     ];
  #   };
  # };

  programs.nix-ld.enable = true;

  time.timeZone = "Asia/Shanghai";
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = hostName;
  networking.domain = "local";
  services.openssh.ports = [222];
  # networking.useNetworkd = true;
  # networking.firewall.allowedTCPPorts = [80 8443 22 wg.listenPort];
  # networking.firewall.allowedUDPPorts = [wg.listenPort];
  networking.firewall.enable = false;
  networking.useNetworkd = true;
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys =
    [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhVCrk3fJC9c7AEW2pknEW072xPnd5Pao9vce9ccIaC warpgate"
    ]
    ++ sensitive.data.authorized-keys;

  # services.getty.autologinUser = "root";

  # boot.loader.systemd-boot.enable = true;
  # boot.loader.systemd-boot.configurationLimit = 5;
  # boot.loader.efi.canTouchEfiVariables = true;
  # boot.initrd.availableKernelModules = [];
  # boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;
  boot.initrd.kernelModules = [];
  # boot.zfs.enabled = true;
  # boot.kernelModules = [];
  # boot.extraModulePackages = [];

  systemd.services.wsl-init = {
    description = "Setup mount & keepalive";
     wantedBy = [ "sysinit.target" ];
        unitConfig = {
      DefaultDependencies = "no";  # Critical for early start
      # After = "systemd-tmpfiles-setup.service local-fs.target";
      # Requires = "local-fs.target";
    };

    path = with pkgs; [
    ];

    serviceConfig = {
      Type = "simple";
    };
    
    script = ''
      #!/bin/sh
      /mnt/c/Windows/system32/wsl.exe --mount '\\.\PHYSICALDRIVE0' --bare || true
      /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe wsl
    '';
  };
  networking.useDHCP = lib.mkForce false;
  networking.hostId = "4e98920d";
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;
  services.resolved.enable = false;
  systemd.network = {
    enable = true;

    # netdevs.wg0 = wg.makeNetdev hostName {
    #   wireguardConfig.PrivateKeyFile = secrets."wireguard.key".path;
    # };
    # networks.wg0 = {
    #   matchConfig.Name = "wg0";
    #   address = ["${wg.configs.${hostName}.address}/24"];
    #   networkConfig = {
    #     IPMasquerade = "ipv4";
    #     IPv4Forwarding = true;
    #   };
    # };
  };
  fileSystems = {
    "/mnt/store" = {
      device = "wd4t/store";
      fsType = "zfs";
    };
    "/mnt/backup" = {
      device = "wd4t/backup";
      fsType = "zfs";
    };
  };
  networking.hosts = {"2408:8210:3070:8b90:2e0:70ff:fec1:41d4" = ["file.thk.hey.xlens.space"];};
  # networking.hosts = {"100.32.32.11" = sniproxy-domains;};
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # hardware.graphics.extraPackages = [ pkgs.amf ];
  # services.udev.extraRules = ''
  #   ATTR{address}=="b0:41:6f:0c:c7:f7", NAME="eth0"
  # '';

  nix.settings.sandbox = "relaxed";
  system.stateVersion = "25.05";
}
# wsl --install --from-file nixos.wsl --location D:\\wsl\nixos

