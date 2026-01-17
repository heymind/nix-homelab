{
  modulesPath,
  pkgs,
  config,
  inputs,
  lib,
  sensitive,
  recipes,
  ...
}: let
  # TODO(adapt): update host name and domains if needed.
  hostName = "homelab_txshhub";
  domains = rec {
    base = "hey.xlens.space";
    frps = "tun.${base}";
    frps_vhost = "*.tun.${base}";
    warpgate_vhost = "*.gate.${base}";
    gitea = "git.${base}";
    woodpecker = "ci.${base}";
    warpgate = "gate.${base}";
    vaultwarden = "pwd.${base}";
  };
  secrets = config.sops.secrets;

  # Example: local recipe wrapper that reuses shared defaults
  gitea-recipe = {
    imports = [
      recipes.server.gitea.defaults
    ];
  };
  woodpecker-recipe = {
    imports = [
      recipes.server.woodpecker.defaults
    ];
    services.woodpecker-server = {
      environmentFile = secrets."woodpecker.env".path;
      environment = {
        # enable when init, first author is admin
        WOODPECKER_OPEN = "true";
        WOODPECKER_GITEA = "true";
        WOODPECKER_GITEA_URL = config.services.gitea.settings.server.ROOT_URL;
        WOODPECKER_GITEA_CLIENT = "f086b8db-a69f-4c5c-ba24-3f1d188e8aa3";
        WOODPECKER_ADMIN = "hey";
      };
    };

    services.woodpecker-agents.agents = {
      local = {
        enable = false;
        package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.woodpecker-agent;
        environment = {
          WOODPECKER_SERVER = "127.0.0.1:${toString config.my.ports.woodpecker.grpc}";
          WOODPECKER_BACKEND = "local";
        };
        environmentFile = [secrets."woodpecker.env".path];
        path = [
          # Needed to clone repos
          pkgs.git
          pkgs.git-lfs
          pkgs.woodpecker-plugin-git
          # Used by the runner as the default shell
          pkgs.bash
          # Most likely to be used in pipeline definitions
          pkgs.coreutils
        ];
      };
    };
  };
  frps-recipe = {
    imports = [
      recipes.server.frps.defaults
    ];
    services.frp.settings.subDomainHost = domains.frps;
    systemd.services.frp.serviceConfig.EnvironmentFile = secrets."frps.env".path;
  };
  vaultwarden-recipe = {
    imports = [
      recipes.server.vaultwarden.defaults
    ];
    services.vaultwarden.environmentFile = secrets."vaultwarden.env".path;
  };
  warpgate-recipe = {
    imports = [
      recipes.server.warpgate.defaults
    ];
  };
  sops-recipe = {
    sops = {
      defaultSopsFile = ../../secrets/${hostName}.yaml;
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      secrets = {
        "acme/${domains.base}.env" = {};
        "woodpecker.env" = {};
        "vaultwarden.env" = {};
        "frps.env" = {};
      };
    };
  };
  services-recipe = {
    services.postgresql.enable = true;
  };
  nginx-acme-recipe = {
    services.nginx = {
      enable = true;
      defaultSSLListenPort = 8443;

      virtualHosts =
        lib.mapAttrs (name: domain: {
          serverName = domain;
          useACMEHost = domains.base;
          addSSL = true;
        })
        domains;
    };
    
    security.acme.acceptTerms = true;
    security.acme.defaults.email = sensitive.data.domain.acmeEmail;
    security.acme.certs.${domains.base} = {
      group = config.services.nginx.group;
      extraDomainNames = ["*.${domains.base}" domains.frps_vhost domains.warpgate_vhost];
      dnsProvider = "cloudflare";
      environmentFile = secrets."acme/${domains.base}.env".path;
    };
  };
  system-recipe = {
    # Configure Go proxy for building Go packages
    systemd.services.nix-daemon.environment.GOPROXY = "https://goproxy.cn,direct";
    
    time.timeZone = "Asia/Shanghai";
    boot.tmp.cleanOnBoot = true;
    zramSwap.enable = true;
    networking.domain = "txshhub";
    networking.hostName = hostName;
    networking.useNetworkd = true;
    networking.useDHCP = false;

    networking.firewall.allowedTCPPorts = [80 8443 22];
    networking.firewall.enable = true;

    systemd.network = {
      enable = true;
      networks.eth0 = {
        matchConfig.Name = "eth0";
        networkConfig.DHCP = "ipv4";
      };
    };

    services.openssh.enable = true;
    programs.zsh.enable = true;
    users.users.root.openssh.authorizedKeys.keys = sensitive.data.authorized-keys;
    services.getty.autologinUser = "root";
    system.stateVersion = "25.11";

    boot.loader.grub.device = "/dev/vda";
    boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = [];
    boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;
    boot.extraModulePackages = [];
    fileSystems."/" = {
      device = "/dev/vda1";
      fsType = "ext4";
    };

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    services.udev.extraRules = ''
      ATTR{address}=="52:54:00:75:24:dc", NAME="eth0"
    '';
  };
in {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    recipes.common.defaults
    recipes.ports.defaults

    recipes.nix.managed
    recipes.nix.optimised
    recipes.nix.ustc-mirror

    recipes.unix.cli-common
     recipes.unix.cli-modern-alts

    gitea-recipe
    woodpecker-recipe
    frps-recipe
    vaultwarden-recipe
    warpgate-recipe
    sops-recipe
    services-recipe
    nginx-acme-recipe
    system-recipe
  ];



}

