{
  modulesPath,
  pkgs,
  config,
  inputs,
  lib,
  sensitive,
  ...
}: let
  hostName = "homelab_rn0";
  # domains = rec {
  #   base = "hey.xlens.space";
  #   frps = "tun.${base}";
  #   frps_vhost = "*.tun.${base}";
  #   gitea = "git.${base}";
  #   woodpecker = "ci.${base}";
  #   headscale = "hs.${base}";
  #   warpgate = "gate.${base}";
  #   vaultwarden = "pwd.${base}";
  # };
  secrets = config.sops.secrets;
  wg = import ../common/wg.nix {inherit lib sensitive;};
in {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../common
  ];

  sops = {
    defaultSopsFile = ../../secrets/${hostName}.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      "wireguard.key" = {
        owner = "systemd-network";
      };
    };
  };
  installed.nginx-sniproxy = {
    enable = true;
    listen = wg.configs.${hostName}.address;
  };
  services.nginx = {
    enable = true;
    defaultSSLListenPort = 8443;

    # virtualHosts =
    #   lib.mapAttrs (name: domain: {
    #     serverName = domain;
    #     useACMEHost = domains.base;
    #     addSSL = true;
    #   })
    #   domains;
  };
  security.acme.acceptTerms = true;
  security.acme.defaults.email = sensitive.data.domain.acmeEmail;
  # security.acme.certs.${domains.base} = {
  #   group = config.services.nginx.group;
  #   extraDomainNames = ["*.${domains.base}" "${domains.frps_vhost}"];
  #   dnsProvider = "cloudflare";
  #   environmentFile = secrets."acme/${domains.base}.env".path;
  # };

  services.mimic = {
    enable = true;
    interfaces.eth0 = {
      enable = true;
      filters = wg.mimic-filters.${hostName};
    };
  };

  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  time.timeZone = "Asia/Shanghai";
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.domain = "local";
  networking.hostName = hostName;
  networking.useNetworkd = true;

  networking.firewall.allowedTCPPorts = [80 8443 22 wg.listenPort];
  networking.firewall.allowedUDPPorts = [wg.listenPort];
  networking.firewall.interfaces."wg0" = {
    allowedTCPPorts = [5201];
    allowedUDPPorts = [5201];
  };
  networking.firewall.enable = true;

  systemd.network = {
    enable = true;
    netdevs.wg0 = wg.makeNetdev hostName {
      wireguardConfig.PrivateKeyFile = secrets."wireguard.key".path;
    };
    networks.wg0 = {
      matchConfig.Name = "wg0";
      address = ["${wg.configs.${hostName}.address}/24"];
      networkConfig = {
        IPMasquerade = "ipv4";
        IPv4Forwarding = true;
      };
    };
    networks.eth0 = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "no";
      networkConfig.IPv4Forwarding = true;
      address = [
        "74.48.37.206/26"
      ];
      routes = [
        {Gateway = "74.48.37.193";}
      ];
    };
  };

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = sensitive.data.authorized-keys;
  services.getty.autologinUser = "root";
  system.stateVersion = "24.11";
  boot.loader.grub.configurationLimit = 2;
  boot.loader.grub.device = "/dev/vda";
  boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi"];
  boot.initrd.kernelModules = ["nvme"];
  boot.kernelModules = ["wireguard"];
  boot.extraModulePackages = [];
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;
  swapDevices = [{device = "/dev/vda2";}];
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services.udev.extraRules = ''
    ATTR{address}=="00:16:3c:7a:75:39", NAME="eth0"
  '';
}
