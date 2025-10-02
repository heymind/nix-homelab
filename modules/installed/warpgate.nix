{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.warpgate;

  warpgate = config.installed.warpgate;
  # host = config.services.nginx.virtualHosts.warpgate;
  # exposePort = config.services.nginx.defaultSSLListenPort;
  utils = import ./_utils.nix;
in {
  options.installed.warpgate = {
    enable = mkEnableOption "";
    ports = {
      web = mkOption {type = types.int;};
      ssh = mkOption {type = types.int;};
    };
  };
  config = mkIf warpgate.enable {
    services.warpgate = {
      enable = true;

      config = {
        external_host = "~";
        database_url = "postgres://warpgate@localhost/warpgate?host=/run/postgresql&sslmode=disable";
        config_provider = "database";
        http = {
          enable = true;
          listen = "127.0.0.1:${toString warpgate.ports.web}";
          certificate = "/var/lib/warpgate/tls.certificate.pem";
          key = "/var/lib/warpgate/tls.key.pem";
        };
        ssh = {
          listen = "0.0.0.0:${toString warpgate.ports.ssh}";
          keys = "/var/lib/warpgate/ssh-keys";
        };
        recordings = {
          enable = true;
          path = "/var/lib/warpgate/recordings";
        };

        #       ssh:
        #   enable: true
        #   listen: "0.0.0.0:222"
        #   keys: /data/ssh-keys
        #   host_key_verification: auto_accept
        # http:
        #   enable: true
        #   listen: "0.0.0.0:8443"
        #   certificate: /data/tls.certificate.pem
        #   key: /data/tls.key.pem
      };
    };

    services.nginx.virtualHosts.warpgate = {
      locations."/" = {
        proxyPass = "https://${cfg.config.http.listen}";
        extraConfig = ''
          proxy_ssl_verify off;
        '';
      };
    };
    services.nginx.virtualHosts.warpgate_vhost = {
      locations."/" = {
        proxyPass = "https://${cfg.config.http.listen}";
        extraConfig = ''
          proxy_ssl_verify off;
        '';
      };
    };
    networking.firewall.allowedTCPPorts = mkIf cfg.config.ssh.enable [warpgate.ports.ssh];

    services.postgresql = utils.ensurePostgresDatabase {name = "warpgate";};
    systemd.services.warpgate.after = [config.systemd.services.postgresql.name];
  };
}
#  ssh txbj 'docker exec txbjng-pg-1  pg_dump -F c -d "postgresql://vaultwarden:vaultwarden@localhost/vaultwarden" ' | sudo -u vaultwarden pg_restore --clean --create -d vaultwarden

