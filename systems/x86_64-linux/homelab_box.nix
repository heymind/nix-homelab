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
    base = "box.${sensitive.data.domain.homelabBase}";
    _wildcard = "*.${base}";
    jellyfin = "v.${base}";
    moviepilot = "mp.${base}";
    openlist = "x.${base}";
    transmission = "bt.${base}";
    aria2 = "dl.${base}";
    immich = "p.${base}";
  };
  hostName = "homelab_box";
  secrets = config.sops.secrets;
  wg = import ../common/wg.nix {inherit lib sensitive;};
  sniproxy-domains = sensitive.data.sniproxy-domains;

  user-hey-recipe = {
    users.extraUsers.hey.extraGroups = ["audio" "podman"];
  };

  user-xmy-recipe = {
    users.users.xmy = {
      group = "xmy";
      uid = 1001;
      home = "/home/xmy";
      createHome = true;
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = ["xmy"];
    };
    users.groups.xmy = {gid = 1001;};
  };

  base-tools-recipe = {
    environment.systemPackages = with pkgs; [
      # tshock
      pueue
      clang
      #   uxplay
      tcpdump
      gptfdisk
      nodejs_22
      wireguard-tools # for vscode remote
      cage
      frp
      dust
      # kodi
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-vaapi
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-libav
      gst_all_1.gst-devtools
      ffmpeg
      vips
      patchelf
      xorg.xeyes
      xorg.xauth
      radeontop
      tdl
      aria2
      miniupnpc
      python3
      uv
      rclone
      google-chrome
      file
      opencv
    ];

    programs.zsh.enable = true;
    services.openssh.settings.X11Forwarding = true;
    networking.nameservers = ["114.114.114.114" "8.8.8.8"];
    programs.mosh.enable = true;
  };

  hardware-recipe = {
    hardware.alsa.enable = true;
    hardware.graphics.enable = true;
    # hardware.pulseaudio.enable = true;
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
    boot.supportedFilesystems = ["zfs" "ntfs"];
    boot.zfs.extraPools = ["wd16t"];
    networking.hostId = "1249b141";
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
      ttl = 600;
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
            name = "boxwood_ssh";
            type = "tcp";
            localIP = "192.168.124.10";
            localPort = 22;
            remotePort = 32022;
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

  moviepilot-recipe = {
    services.nginx.virtualHosts.moviepilot = {
      locations."/" = {
        extraConfig = ''
          resolver 10.88.0.1 valid=30s ipv6=off;
          set $upstream http://moviepilot:3000;
          proxy_pass $upstream;
        '';
        recommendedProxySettings = true;
      };
    };

    virtualisation.oci-containers.containers = {
      moviepilot = {
        image = "ghcr.io/jxxghp/moviepilot:2.8.0";
        volumes = [
          "/mnt:/mnt"
          "/var/lib/moviepilot:/config"
          "/var/cache/moviepilot:/moviepilot/.cache"
        ];
        environment = {
          TZ = "Asia/Shanghai";
          SUPERUSER = "hey";
          SUPERUSER_PASSWORD = "initpass0";
          PUID = "1000";
          PGID = "1000";
          UMASK = "0000";
        };
      };
    };
  };

  avahi-recipe = {
    services.avahi.enable = true;
    services.avahi.publish.enable = true;
    services.avahi.openFirewall = true;
    services.avahi.publish.userServices = true;
    # Enable mDNS since we're already using Avahi anyways
    services.avahi.nssmdns4 = true;
    services.avahi.nssmdns6 = true;
  };

  monitoring-recipe = {
    installed.monitoring = {
      vmagent = true;
      vmagent-remote = wg.configs.homelab_txcdhub.address;
      node_exporter = true;
      nginx = true;
    };
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
      external-ui = "ui"; # Relative path, will be handled by services.mihomo.webui
      secret = "";

      # TUN mode configuration
      tun = {
        enable = false;
        stack = "mixed"; # or "system" or "gvisor"
        auto-route = true;
        auto-detect-interface = true;
        dns-hijack = [
          "any:53"
        ];
      };

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
          url = "https://zymsubap.kkhhyytt.cn/api/v1/client/subscribe?token=88cbf188985b1ba67b31217d1961893c";
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
      tunMode = true; # Enable TUN mode permissions
      webui = pkgs.unstable.metacubexd;
      configFile = yamlFormat.generate "mihomo-config.yaml" mihomoConfig;
    };
  };
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../common
    mihomo-recipe
    user-hey-recipe
    user-xmy-recipe
    base-tools-recipe
    hardware-recipe
    container-recipe
    zfs-recipe
    acme-recipe
    cloudflare-ddns-recipe
    nginx-recipe
    frp-recipe
    download-services-recipe
    moviepilot-recipe
    avahi-recipe
    monitoring-recipe
  ];

  sops = {
    defaultSopsFile = ../../secrets/homelab_box.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      "wireguard.key" = {
        owner = "systemd-network";
      };
    };
  };

  installed.jellyfin.enable = true;
  services.postgresql.enable = true;
  installed.immich.enable = true;

  time.timeZone = "Asia/Shanghai";
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "boxwood";
  networking.domain = "local";
  networking.useNetworkd = true;
  networking.firewall.allowedTCPPorts = [80 60443 22 wg.listenPort];
  networking.firewall.allowedUDPPorts = [wg.listenPort];
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
  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "amdgpu"];
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  fileSystems =
    {
      "/" = {
        device = "/dev/disk/by-uuid/3ed763a9-39ff-4e0b-b07b-2b7587faab56";
        fsType = "xfs";
      };

      "/boot" = {
        device = "/dev/disk/by-uuid/68F2-58C6";
        fsType = "vfat";
        options = ["fmask=0077" "dmask=0077"];
      };
    }
    // (let
      zfsMounts = {
        "/mnt/store" = "wd16t/store";
        "/mnt/backup" = "wd16t/backup";
        "/mnt/media/personal" = "wd16t/media/personal";
        "/mnt/media/videos" = "wd16t/media/videos";
        "/var/lib/jellyfin/study" = "wd16t/media/study";
      };
    in
      lib.mapAttrs (mountPoint: device: {
        inherit device;
        fsType = "zfs";
        options = ["nofail"];
        neededForBoot = false;
      })
      zfsMounts)
    // (let
      bindMounts = {
        "/var/lib/immich/library/admin" = "/mnt/media/personal/immich";
        "/var/lib/transmission/Downloads/media" = "/mnt/media/videos/downloads/transmission";
      };
    in
      lib.mapAttrs (mountPoint: device: {
        inherit device;
        fsType = "none";
        options = ["bind" "nofail"];
        neededForBoot = false;
      })
      bindMounts);

  swapDevices = [
    {device = "/dev/disk/by-uuid/19ef33dc-1720-4769-b45f-03968110ab01";}
  ];

  systemd.network = {
    enable = true;
    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "yes";
    };
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
  };
  # networking.hosts = {"100.32.32.11" = sniproxy-domains;};
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # hardware.graphics.extraPackages = [ pkgs.amf ];
  services.udev.extraRules = ''
    ATTR{address}=="b0:41:6f:0c:c7:f7", NAME="eth0"
  '';

  services.mimic = {
    enable = true;
    interfaces.eth0 = {
      enable = true;
      filters = wg.mimic-filters.${hostName};
      xdpMode = "skb";
    };
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      libglvnd
      glib
    ];
  };

  nix.settings.sandbox = "relaxed";
  system.stateVersion = "25.05";
}
