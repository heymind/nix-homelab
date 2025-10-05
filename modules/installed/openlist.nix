{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.installed.openlist;
in {
  options.installed.openlist = {
    enable = mkEnableOption "OpenList service";
    
    ports = {
      web = mkOption {
        type = types.int;
        description = "Port for the OpenList web service";
      };
    };

    package = mkOption {
      type = types.package;
      default = pkgs.unstable.openlist;
      description = "OpenList package to use";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/openlist";
      description = "Directory to store OpenList data";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.openlist = {
      description = "OpenList - shareable lists service";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/openlist";
        Restart = "on-failure";
        RestartSec = "5s";
        
        # Security hardening
        DynamicUser = true;
        StateDirectory = "openlist";
        SupplementaryGroups = "1000";
        PrivateTmp = false;  # Use system tmp instead of private tmp
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
      };

      environment = {
        OPLISTDX_HTTP_PORT = toString cfg.ports.web;
        OPLISTDX_DATA = cfg.dataDir;
        OPLISTDX_TEMP = "/tmp/openlist";
      };
    };

    # Nginx reverse proxy
    services.nginx.virtualHosts.openlist = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.ports.web}";
        recommendedProxySettings = true;
        extraConfig = ''
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };
    };
  };
}

