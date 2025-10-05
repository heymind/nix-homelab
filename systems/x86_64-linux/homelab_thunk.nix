{
  modulesPath,
  pkgs,
  config,
  inputs,
  lib,
  sensitive,
  ...
}: let
  domains = rec {
    base = "thk.${sensitive.data.domain.homelabBase}";
    _wildcard = "*.${base}";
    transmission = "bt.${base}";
    aria2 = "dl.${base}";
    openlist = "x.${base}";
  };
  hostName = "homelab_thunk";
  secrets = config.sops.secrets;
  wg = import ../common/wg.nix {inherit lib sensitive;};
  sniproxy-domains = sensitive.data.sniproxy-domains;

  user-hey-recipe = {
    users.users.hey = {
      group = "hey";
      uid = 1000;
      home = "/home/hey";
      createHome = true;
      isNormalUser = true;
      extraGroups = ["audio" "podman"];
    };
    users.groups.hey = {gid = 1000;};
  };

  base-tools-recipe = {
    environment.systemPackages = with pkgs; [
      pueue
      dust
      python3
      uv
      rclone
      file
      unstable.cursor-cli
      pv
      frp
      aria2
    ];

    programs.zsh.enable = true;
    services.openssh.settings.X11Forwarding = true;
    networking.nameservers = ["114.114.114.114" "8.8.8.8"];
    programs.mosh.enable = true;
  };

  container-recipe = {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    virtualisation.containers.enable = true;
  };

  zfs-recipe = {
    boot.supportedFilesystems = ["ext4" "vfat" "zfs"];
    boot.zfs.forceImportRoot = false;
    boot.zfs.forceImportAll = false;
    networking.hostId = "1009b112";
    
    # ZFS configuration - no auto-mount
    services.zfs.autoSnapshot.enable = false;
    services.zfs.autoScrub.enable = false;
  };

  acme-recipe = {
    sops.secrets."acme/${sensitive.data.domain.homelabRoot}.env" = {};

    security.acme = {
      acceptTerms = true;
      defaults.email = sensitive.data.domain.acmeEmail;
      certs.${domains.base} = {
        group = config.services.nginx.group;
        extraDomainNames = [domains._wildcard];
        dnsProvider = "cloudflare";
        environmentFile = secrets."acme/${sensitive.data.domain.homelabRoot}.env".path;
      };
    };
  };

  cloudflare-ddns-recipe = {
    sops.templates."cloudflare-ddns.env".content = ''
      CF_API_TOKEN=${config.sops.placeholder."cloudflare.token"}
    '';
    sops.secrets."cloudflare.token" = {};

    installed.cloudflare-ddns = {
      enable = true;
      domain = domains.base;
      zoneId = "9b2256c376cd3586421fd815e3ac3c6c";
      environmentFile = config.sops.templates."cloudflare-ddns.env".path;
      updateA = true;
      updateAAAA = true;
      ipv6Interface = "eth0";
      ttl = 60;
      interval = "30s";
    };
  };

  nginx-recipe = {
    services.nginx = {
      enable = true;
      defaultSSLListenPort = 60443;

      virtualHosts =
        lib.mapAttrs (name: domain: {
          serverName = domain;
          useACMEHost = domains.base;
          addSSL = true;
        })
        domains;
    };
  };

  frp-recipe = {
    sops.secrets."frpc.env" = {};

    services.frp = {
      enable = true;
      role = "client";
      settings = {
        serverAddr = "tun.hey.${sensitive.data.domain.homelabRoot}";
        serverPort = 8443;
        transport.protocol = "wss";
        auth.method = "token";
        auth.token = "{{ .Envs.AUTH_TOKEN }}";

        proxies = [
          {
            name = "thunk_ssh";
            type = "tcp";
            localIP = "127.0.0.1";
            localPort = 22;
            remotePort = 32023;
          }
          {
            name = "thunk_https";
            type = "tcp";
            localIP = "127.0.0.1";
            localPort = 60443;
            remotePort = 60123;
          }
        ];
      };
    };
    
    systemd.services.frp.serviceConfig.EnvironmentFile = secrets."frpc.env".path;
  };

  download-services-recipe = {
    sops.secrets."htpasswd" = {
      owner = "nginx";
    };

    installed.transmission = {
      enable = true;
      basicAuthFile = secrets."htpasswd".path;
    };

    services.transmission.settings = {
      rpc-host-whitelist-enabled = true;
      rpc-host-whitelist = domains.transmission;
      rpc-bind-address = "0.0.0.0";
    };

    installed.aria2 = {
      enable = true;
      basicAuthFile = secrets."htpasswd".path;
    };
  };

  openlist-recipe = {
    installed.openlist.enable = true;
  };

  mihomo-recipe = let
    yamlFormat = pkgs.formats.yaml {};
    mihomoConfig = {
      mixed-port = 7890;
      allow-lan = true;
      bind-address = "*";
      mode = "rule";
      log-level = "info";
      ipv6 = true;
      external-controller = "0.0.0.0:9090";
      external-ui = "${pkgs.unstable.metacubexd}/share/metacubexd";
      secret = "";
      
      profile = {
        store-selected = true;
        store-fake-ip = true;
      };
      
      dns = {
        enable = true;
        listen = "0.0.0.0:1053";
        enhanced-mode = "fake-ip";
        fake-ip-range = "198.18.0.1/16";
        nameserver = [
          "223.5.5.5"
          "119.29.29.29"
        ];
        fallback = [
          "8.8.8.8"
          "1.1.1.1"
        ];
      };
      
      proxy-providers = {
        subscription = {
          type = "http";
          url = sensitive.data.mihomo.subscriptionUrl;
          interval = 86400;
          path = "./subscription.yaml";
          health-check = {
            enable = true;
            interval = 600;
            url = "http://www.gstatic.com/generate_204";
          };
        };
      };
      
      proxy-groups = [
        {
          name = "PROXY";
          type = "select";
          use = ["subscription"];
        }
        {
          name = "Auto";
          type = "url-test";
          use = ["subscription"];
          url = "http://www.gstatic.com/generate_204";
          interval = 300;
        }
      ];
      
      rules = [
        "GEOIP,CN,DIRECT"
        "MATCH,PROXY"
      ];
    };
  in {
    services.mihomo = {
      enable = true;
      webui = pkgs.unstable.metacubexd;
      configFile = yamlFormat.generate "mihomo-config.yaml" mihomoConfig;
    };
  };
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../common
    user-hey-recipe
    base-tools-recipe
    container-recipe
    zfs-recipe
    # acme-recipe
    # cloudflare-ddns-recipe
    # nginx-recipe
    # frp-recipe
    # download-services-recipe
    openlist-recipe
    mihomo-recipe
  ];
  
  sops = {
    defaultSopsFile = ../../secrets/homelab_thunk.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      # "wireguard.key" = {
      #   owner = "systemd-network";
      # };
    };
  };

  time.timeZone = "Asia/Shanghai";
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "thunk";
  networking.domain = domains.base;
  networking.useNetworkd = true;
  networking.firewall.allowedTCPPorts = [80 60443 22]; # wg.listenPort];
  # networking.firewall.allowedUDPPorts = [wg.listenPort];
  networking.firewall.enable = false;

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys =
    [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhVCrk3fJC9c7AEW2pknEW072xPnd5Pao9vce9ccIaC warpgate"
    ]
    ++ sensitive.data.authorized-keys;
  services.getty.autologinUser = "root";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" "nvme"];
  boot.initrd.kernelModules = ["nvme"];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/a8efb811-a8ac-4a38-81ae-9526fe0623b1";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/EA08-2D15";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/d8118907-ac43-4d06-92a9-11b47d74c743";}
  ];

  

  systemd.network = {
    enable = true;
    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "yes";
    };
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
  
  # networking.hosts = {"100.32.32.11" = sniproxy-domains;};
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  
  # Rename network interface to eth0
  services.udev.extraRules = ''
    ATTR{address}=="00:e0:70:c1:41:d4", NAME="eth0"
  '';

  nix.settings.sandbox = "relaxed";
  system.stateVersion = "25.05";
}
