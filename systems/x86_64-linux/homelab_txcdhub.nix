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
  hostName = "homelab_txcdhub";
  domains = rec {
    base = "hey.xlens.space";
    frps = "tun.${base}";
    frps_vhost = "*.tun.${base}";
    warpgate_vhost = "*.gate.${base}";
    gitea = "git.${base}";
    woodpecker = "ci.${base}";
    headscale = "hs.${base}";
    warpgate = "gate.${base}";
    vaultwarden = "pwd.${base}";
  };
  secrets = config.sops.secrets;
  wg = import ../common/wg.nix {inherit lib sensitive;};
in {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    recipes.common.defaults
    recipes.ports.defaults
    # "${inputs.nixpkgs-unstable}/nixos/modules/services/security/pocket-id.nix"
    # "${inputs.nixpkgs-unstable}/nixos/modules/services/continuous-integration/woodpecker/server.nix"
  ];

  services.pocket-id.package = pkgs.unstable.pocket-id;
  services.woodpecker-server.package = pkgs.unstable.woodpecker-server;

  sops = {
    defaultSopsFile = ../../secrets/${hostName}.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      "acme/${domains.base}.env" = {};
      "woodpecker.env" = {};
      "vaultwarden.env" = {};
      "warpgate.env" = {};
      "frps.env" = {};
      "tailscale.key" = {};
      "wireguard.key" = {
        owner = "systemd-network";
      };
    };
  };
  installed.vaultwarden.enable = true;
  services.vaultwarden = {
    environmentFile = secrets."vaultwarden.env".path;
  };

  installed.headscale.enable = true;
  services.headscale.settings = {
    dns = {
      magic_dns = false;
    };
  };

  installed.warpgate.enable = true;
  services.warpgate = {
    config.ssh = {
      enable = true;
      host_key_verification = "auto_accept";
    };
    environmentFile = secrets."warpgate.env".path;
  };

  installed.gitea.enable = true;
  installed.woodpecker.enable = true;
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
      enable = true;
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
  installed.frps.enable = true;
  services.frp.settings.subDomainHost = domains.frps;
  systemd.services.frp.serviceConfig.EnvironmentFile = secrets."frps.env".path;

  installed.monitoring = {
    grafana = true;
    victoriametrics = true;
    node_exporter = true;
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = secrets."tailscale.key".path;
    extraUpFlags = ["--login-server=${domains.headscale}"];
  };

  services.postgresql.enable = true;
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
  networking.useDHCP = false;

  networking.firewall.allowedTCPPorts = [80 8443 22 wg.listenPort];
  networking.firewall.allowedUDPPorts = [wg.listenPort];
  # enable remote write for victoriametrics
  networking.firewall.interfaces.wg0.allowedTCPPorts = [config.my.ports.monitoring.victoriametrics];
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
      networkConfig.DHCP = "ipv4";
      address = ["2402:4e00:c000:1000:5030:c3f0:1412:0/128"];
      routes = [
        {Gateway = "fe80::ecff:ffff:feff:ffff";}
      ];
    };
  };

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = sensitive.data.authorized-keys;
  services.getty.autologinUser = "root";
  system.stateVersion = "24.11";

  boot.loader.grub.device = "/dev/vda";
  boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["wireguard"];
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;
  boot.extraModulePackages = [];
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services.udev.extraRules = ''
    ATTR{address}=="52:54:00:df:38:41", NAME="eth0"
  '';
}
