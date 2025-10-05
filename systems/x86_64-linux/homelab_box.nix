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
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../common
    {
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
    }
  ];
  sops = {
    defaultSopsFile = ../../secrets/homelab_box.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      "frpc.env" = {};
      "wireguard.key" = {
        owner = "systemd-network";
      };
      "acme/${sensitive.data.domain.homelabRoot}.env" = {};
      "cloudflare.token" = {};
      "htpasswd" = {
        owner = "nginx";
      };
    };
    templates = {
      "ddns-updater-config.json".content = ''
        {
          "settings": [
            {
              "provider": "cloudflare",
              "zone_identifier": "9b2256c376cd3586421fd815e3ac3c6c",
              "domain": "${domains.base}",
              "ttl": 600,
              "ip_version":"ipv4",
              "token": "${config.sops.placeholder."cloudflare.token"}"
            },
            {
              "provider": "cloudflare",
              "zone_identifier": "9b2256c376cd3586421fd815e3ac3c6c",
              "domain": "${domains.base}",
              "ttl": 600,
              "ip_version":"ipv6",
              "token": "${config.sops.placeholder."cloudflare.token"}"
            }
          ]
        }
      '';
    };
  };
  hardware.alsa.enable = true;
  hardware.graphics.enable = true;
  # hardware.pulseaudio.enable = true;
  users = {
    users.xmy = {
      group = "xmy";
      uid = 1001;
      home = "/home/xmy";
      createHome = true;
      isNormalUser = true;
      shell = pkgs.zsh;

      extraGroups = ["xmy"];
    };
    groups.xmy = {gid = 1001;};
  };

  users.extraUsers.hey.extraGroups = ["audio" "podman"];
  environment.systemPackages = with pkgs; [
    pueue
    clang
    uxplay
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
    stash
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

  services.ddns-updater = {
    enable = true;
    environment = {
      CONFIG_FILEPATH = ''/run/credentials/ddns-updater.service/config.json'';
      RESOLVER_ADDRESS = "1.1.1.1:53";
      PERIOD = "30s";
      PUBLICIP_FETCHERS = "http";
      PUBLICIP_HTTP_PROVIDERS = "ifconfig,ipinfo,url:https://ip.sb";
      PUBLICIPV4_HTTP_PROVIDERS = "url:https://myip.ipip.net,ipleak,icanhazip";
      PUBLICIPV6_HTTP_PROVIDERS = "ipleak,icanhazip";
    };
  };
  systemd.services.ddns-updater.serviceConfig.LoadCredential = "config.json:${config.sops.templates."ddns-updater-config.json".path}";

  programs.zsh.enable = true;
  services.openssh.settings.X11Forwarding = true;
  hardware.opengl.enable = true;
  networking.nameservers = ["114.114.114.114" "8.8.8.8"];
  # services.smartdns = {
  #   enable = true;
  #   settings = {
  #     server = ["8.8.8.8" "114.114.114.114"];
  #     server-tls = ["1.1.1.1"];
  #     domain-set = ["-name sniproxy -type list -file ${./installed/sniproxy-domains.txt}"];
  #     address = ["/domain-set:sniproxy/100.32.32.11"];
  #   };
  # };
  # services.resolved = {
  #   # Disable local DNS stub listener on 127.0.0.53
  #   extraConfig = ''
  #     DNSStubListener=no
  #   '';
  # };
  programs.mosh.enable = true;
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
  # services.woodpecker-agents.agents = {
  #   local = {
  #     enable = true;
  #     package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.woodpecker-agent;
  #     environment = {
  #       WOODPECKER_SERVER = "127.0.0.1:${toString config.installed.woodpecker.ports.grpc}";
  #       WOODPECKER_BACKEND = "local";
  #     };
  #     environmentFile = [secrets."woodpecker.env".path];
  #     path = [
  #       # Needed to clone repos
  #       pkgs.git
  #       pkgs.git-lfs
  #       pkgs.woodpecker-plugin-git
  #       # Used by the runner as the default shell
  #       pkgs.bash
  #       # Most likely to be used in pipeline definitions
  #       pkgs.coreutils
  #     ];
  #   };
  # };
  # installed.frps.enable = true;
  # systemd.services.frp.serviceConfig.EnvironmentFile = secrets."frps.env".path;

  # services.tailscale = {
  #   enable = true;
  #   openFirewall = true;
  #   authKeyFile = secrets."tailscale.key".path;
  #   extraUpFlags = ["--login-server=${domains.headscale}"];
  # };
  # services.cage.enable = true;
  # services.displayManager.defaultSession = "cage";
  # programs.adb.enable = true;
  # services.cage.program = "/run/current-system/sw/bin/uxplay -fs";
  # services.cage.user = "root";
  # virtualisation.waydroid.enable = true;

  installed.monitoring = {
    vmagent = true;
    vmagent-remote = wg.configs.homelab_txcdhub.address;
    node_exporter = true;

    nginx = true;
  };

  installed.jellyfin.enable = true;
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
  # services.aria2.

  # services.nginx = {
  #   recommendedProxySettings = true;
  #   additionalModules = [pkgs.nginxModules.dav];
  #   virtualHosts."_" = {
  #     locations."/videos" = {
  #       root = "/home/hey/Workspace/funtime";
  #       extraConfig = ''
  #         dav_methods PUT DELETE MKCOL COPY MOVE;
  #         dav_ext_methods PROPFIND OPTIONS;
  #         dav_access user:rw group:rw all:r;

  #         # Allow all WebDAV methods
  #         if ($request_method = 'OPTIONS') {
  #           add_header 'Access-Control-Allow-Origin' '*';
  #           add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE, COPY, MOVE, MKCOL, PROPFIND';
  #           add_header 'Access-Control-Allow-Headers' 'Authorization,DNT,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type';
  #           add_header 'Access-Control-Max-Age' 1728000;
  #           add_header 'Content-Type' 'text/plain charset=UTF-8';
  #           add_header 'Content-Length' 0;
  #           return 204;
  #         }
  #       '';
  #     };
  #   };
  # };

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
      };
    };
  };

  services.postgresql.enable = true;

  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.avahi.openFirewall = true;
  services.avahi.publish.userServices = true;

  # We also have enabled mDNS since we're already using Avahi anyways.
  services.avahi.nssmdns4 = true;
  services.avahi.nssmdns6 = true;

  services.mimic = {
    enable = true;
    interfaces.eth0 = {
      enable = true;
      filters = wg.mimic-filters.${hostName};
      xdpMode = "skb";
    };
  };

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

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      libglvnd
      glib
    ];
  };

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
  boot.supportedFilesystems = ["zfs" "ntfs"];
  boot.zfs.extraPools = ["wd4t"];
  networking.hostId = "1249b141";

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
        "/mnt/store" = "wd4t/store";
        "/mnt/backup" = "wd4t/backup";
        "/mnt/media/personal" = "wd4t/media/personal";
        "/mnt/media/videos" = "wd4t/media/videos";
      };
    in
      lib.mapAttrs (mountPoint: device: {
        inherit device;
        fsType = "zfs";
        options = ["nofail"];
        neededForBoot = false;
      })
      zfsMounts);
  # // (let
  #   bindMounts = {
  #     "/var/lib/transmission/Downloads" = "/mnt/store/downloads";
  #     "/var/lib/aria2c/Downloads" = "/mnt/store/downloads";
  #   };
  # in
  #   lib.mapAttrs (mountPoint: device: {
  #     inherit device;
  #     fsType = "none";
  #     options = ["bind" "nofail"];
  #     neededForBoot = false;
  #   })
  #   bindMounts);

  swapDevices = [
    {device = "/dev/disk/by-uuid/19ef33dc-1720-4769-b45f-03968110ab01";}
  ];
  virtualisation.podman = {
    enable = true;

    # 创建 `docker` 别名指向 `podman`
    dockerCompat = true;

    # 需要为无根容器启用
    defaultNetwork.settings.dns_enabled = true;
  };

  # 启用容器相关服务
  virtualisation.containers.enable = true;
  # networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;
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
  networking.hosts = {"100.32.32.11" = sniproxy-domains;};
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # hardware.graphics.extraPackages = [ pkgs.amf ];
  services.udev.extraRules = ''
    ATTR{address}=="b0:41:6f:0c:c7:f7", NAME="eth0"
  '';

  nix.settings.sandbox = "relaxed";
  system.stateVersion = "25.05";
}
