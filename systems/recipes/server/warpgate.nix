{
  defaults = {config, lib, ux, ...}: let
    ports = config.my.ports.warpgate;
    cfg = config.services.warpgate;
  in {
    services.warpgate = {
      enable = lib.mkDefault true;
      settings = {
        database_url = "postgres://warpgate@localhost/warpgate?host=/run/postgresql&sslmode=disable";
        external_host = null;
        ssh = {
          enable = true;
          listen = "0.0.0.0:${toString ports.ssh}";
          host_key_verification = lib.mkDefault "auto_accept";
        };
        http = {
          enable = true;
          listen = "127.0.0.1:${toString ports.web}";
        };
        recordings = {
          enable = true;
          path = "/var/lib/warpgate/recordings";
        };
      };
    };

    services.nginx.virtualHosts.warpgate = {
      locations."/" = {
        proxyPass = "https://${cfg.settings.http.listen}";
        extraConfig = ''
          proxy_ssl_verify off;
        '';
      };
    };
    services.nginx.virtualHosts.warpgate_vhost = {
      locations."/" = {
        proxyPass = "https://${cfg.settings.http.listen}";
        extraConfig = ''
          proxy_ssl_verify off;
        '';
      };
    };
    networking.firewall.allowedTCPPorts = [ports.ssh];

    services.postgresql = ux.server.ensurePostgresDatabase {name = "warpgate";};
    systemd.services.warpgate.after = [config.systemd.services.postgresql.name];
  };
}

