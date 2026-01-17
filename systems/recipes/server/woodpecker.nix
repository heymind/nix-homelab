{
  defaults = {config, lib, ux, ...}: let
    ports = config.my.ports.woodpecker;
    host = config.services.nginx.virtualHosts.woodpecker;
    exposePort = config.services.nginx.defaultSSLListenPort;
  in {
    services.woodpecker-server = {
      enable = true;
      environment = {
        WOODPECKER_DATABASE_DRIVER = lib.mkDefault "postgres";
        WOODPECKER_DATABASE_DATASOURCE = lib.mkDefault
          "postgres://woodpecker@/woodpecker?host=/run/postgresql&sslmode=disable";
        WOODPECKER_SERVER_ADDR = lib.mkDefault "127.0.0.1:${toString ports.web}";
        WOODPECKER_GRPC_ADDR = lib.mkDefault "127.0.0.1:${toString ports.grpc}";
        WOODPECKER_HOST = lib.mkDefault
          "https://${host.serverName}:${toString exposePort}";
      };
    };

    systemd.services.woodpecker-server.serviceConfig = {
      User = "woodpecker";
      Group = "woodpecker";
    };

    services.nginx.virtualHosts.woodpecker = {
      locations."/".proxyPass =
        "http://${config.services.woodpecker-server.environment.WOODPECKER_SERVER_ADDR}";
      locations."/proto.Woodpecker/" = {
        extraConfig = ''
          grpc_pass grpc://${config.services.woodpecker-server.environment.WOODPECKER_GRPC_ADDR};
        '';
      };
    };

    services.postgresql = ux.server.ensurePostgresDatabase {name = "woodpecker";};
    systemd.services.woodpecker.after = [config.systemd.services.postgresql.name];
  };
}

