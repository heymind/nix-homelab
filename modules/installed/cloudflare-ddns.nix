{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.installed.cloudflare-ddns;
in {
  options.installed.cloudflare-ddns = {
    enable = mkEnableOption "Cloudflare DDNS updater" // {
      description = lib.mdDoc "Whether to enable Cloudflare DDNS automatic updates";
    };

    domain = mkOption {
      type = types.str;
      description = lib.mdDoc "Domain name to update (e.g., ddns.example.com)";
      example = "home.example.com";
    };

    apiToken = mkOption {
      type = types.str;
      default = "";
      description = lib.mdDoc ''
        Cloudflare API token with DNS edit permissions.
        Get it from: https://dash.cloudflare.com/profile/api-tokens
        
        Note: This will be stored in the Nix store. Use environmentFile for secrets.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = lib.mdDoc ''
        Environment file containing secrets (e.g., CF_API_TOKEN=xxx).
        Recommended for secrets management (e.g., sops-nix).
      '';
      example = "/run/secrets/cloudflare-ddns.env";
    };

    zoneId = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        Cloudflare Zone ID for your domain.
        Find it in your domain's overview page on Cloudflare dashboard.
      '';
    };

    updateA = mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc "Whether to update A record (IPv4)";
    };

    updateAAAA = mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc "Whether to update AAAA record (IPv6)";
    };

    ipv6Interface = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = lib.mdDoc ''
        Network interface for IPv6 address (required if updateAAAA is true).
        Use `ip addr` or `ifconfig` to find your interface name.
      '';
      example = "eth0";
    };

    ttl = mkOption {
      type = types.int;
      default = 300;
      description = lib.mdDoc "DNS record TTL in seconds";
    };

    proxied = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Enable Cloudflare proxy (orange cloud).
        When enabled, actual IP is hidden behind Cloudflare.
      '';
    };

    interval = mkOption {
      type = types.str;
      default = "30s";
      description = lib.mdDoc ''
        Update interval in systemd timer format.
        Examples: "30s", "5min", "1h"
      '';
      example = "5min";
    };

    user = mkOption {
      type = types.str;
      default = "cloudflare-ddns";
      description = lib.mdDoc "User account under which the service runs";
    };

    group = mkOption {
      type = types.str;
      default = "cloudflare-ddns";
      description = lib.mdDoc "Group under which the service runs";
    };
  };

  config = mkIf cfg.enable {
    # Assertions to validate configuration
    assertions = [
      {
        assertion = cfg.updateAAAA -> cfg.ipv6Interface != null;
        message = "installed.cloudflare-ddns.ipv6Interface must be set when updateAAAA is enabled";
      }
      {
        assertion = cfg.updateA || cfg.updateAAAA;
        message = "At least one of updateA or updateAAAA must be enabled";
      }
    ];

    # Install the package
    environment.systemPackages = [pkgs.cloudflare-ddns];

    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "Cloudflare DDNS service user";
    };

    users.groups.${cfg.group} = {};

    # Create systemd service
    systemd.services.cloudflare-ddns = {
      description = "Cloudflare DDNS Update";
      documentation = ["https://github.com/yourusername/nix-homelab"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.cloudflare-ddns}/bin/cloudflare-ddns";
        User = cfg.user;
        Group = cfg.group;
        
        # Security hardening
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        ProtectClock = true;
        
        # Allow access to network interfaces for IPv6
        PrivateDevices = false; # Need access to /sys/class/net
        ProtectProc = "invisible";
        ProcSubset = "pid";
        
        # Restart policy
        Restart = "on-failure";
        RestartSec = "30s";
      } // optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };

      environment = {
        CF_ZONE_ID = cfg.zoneId;
        CF_DOMAIN = cfg.domain;
        CF_UPDATE_A = if cfg.updateA then "true" else "false";
        CF_UPDATE_AAAA = if cfg.updateAAAA then "true" else "false";
        CF_TTL = toString cfg.ttl;
        CF_PROXIED = if cfg.proxied then "true" else "false";
      } // optionalAttrs (cfg.apiToken != "") {
        CF_API_TOKEN = cfg.apiToken;
      } // optionalAttrs (cfg.ipv6Interface != null) {
        CF_IPV6_INTERFACE = cfg.ipv6Interface;
      };
    };

    # Create systemd timer
    systemd.timers.cloudflare-ddns = {
      description = "Cloudflare DDNS Update Timer";
      documentation = ["https://github.com/yourusername/nix-homelab"];
      wantedBy = ["timers.target"];

      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.interval;
        Unit = "cloudflare-ddns.service";
        Persistent = false; # Run missed timers on boot
        AccuracySec = "1s";
      };
    };
  };
}

