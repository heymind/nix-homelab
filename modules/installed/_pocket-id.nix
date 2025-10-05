{domain}: {
  config,
  pkgs,
  ...
}: let
  cfg = config.services.pocket-id;
  ports = (import ../../common/ports.nix).pocket-id;
in {
  services.pocket-id = {
    enable = true;

    settings = {
      PORT = toString ports.web;
      TRUST_PROXY = true;
      INTERNAL_BACKEND_URL = "http://localhost:${toString ports.backend}";
      BACKEND_PORT = toString ports.backend;

      DB_PROVIDER = "postgres";
      DB_CONNECTION_STRING = "postgres://pocket-id@localhost/pocket-id?host=/run/postgresql";
    };
  };

  systemd.services.pocket-id-backend = {
    after = [config.systemd.services.postgresql.name];
    serviceConfig.RestrictAddressFamilies = ["AF_UNIX"];
  };
  services.nginx.virtualHosts.${domain} = {
    locations."/api".proxyPass = "http://127.0.0.1:${cfg.settings.BACKEND_PORT}";
    locations."/".proxyPass = "http://127.0.0.1:${cfg.settings.PORT}";
     locations."/.well-known".proxyPass = "http://127.0.0.1:${cfg.settings.PORT}";
    
  };

  services.postgresql = {
    ensureDatabases = ["pocket-id"];
    ensureUsers = [
      {
        name = "pocket-id";
        ensureClauses.login = true;
        ensureDBOwnership = true;
      }
    ];
  };
}
