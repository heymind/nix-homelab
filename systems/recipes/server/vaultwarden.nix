{
  defaults = {config, lib, ux, ...}: let
    ports = config.my.ports.vaultwarden;
    host = config.services.nginx.virtualHosts.vaultwarden;
    exposePort = config.services.nginx.defaultSSLListenPort;
  in {
    services.vaultwarden = {
      enable = true;
      dbBackend = "postgresql";
      config = {
        DATABASE_URL = lib.mkDefault
          "postgres://vaultwarden@/vaultwarden?host=/run/postgresql&sslmode=disable";
        ROCKET_ADDRESS = lib.mkDefault "127.0.0.1";
        ROCKET_PORT = lib.mkDefault (toString ports.web);
        DOMAIN = lib.mkDefault "https://${host.serverName}:${toString exposePort}";
      };
    };

    services.nginx.virtualHosts.vaultwarden = {
      locations."/".proxyPass =
        "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
    };

    services.postgresql = ux.server.ensurePostgresDatabase {name = "vaultwarden";};
    systemd.services.vaultwarden.after = [config.systemd.services.postgresql.name];
  };
}

