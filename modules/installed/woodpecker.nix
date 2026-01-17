{
  lib,
  config,
  pkgs,
  inputs,
  ux,
  ...
}:
with lib; let
  cfg = config.services.woodpecker-server;
  woodpecker = config.installed.woodpecker;
  host = config.services.nginx.virtualHosts.woodpecker;
  exposePort = config.services.nginx.defaultSSLListenPort;
in {
  options.installed.woodpecker = {
    enable = mkEnableOption "";
    ports = {
      web = mkOption {type = types.int;};
      grpc = mkOption {type = types.int;};
    };
  };
  config = mkIf woodpecker.enable {
    services.woodpecker-server = {
      # https://woodpecker-ci.org/docs/administration/configuration/server#server_addr
      enable = true;

      environment = {
        WOODPECKER_DATABASE_DRIVER = "postgres";
        WOODPECKER_DATABASE_DATASOURCE = "postgres://woodpecker@/woodpecker?host=/run/postgresql&sslmode=disable";
        WOODPECKER_SERVER_ADDR = "127.0.0.1:${toString woodpecker.ports.web}";
        WOODPECKER_GRPC_ADDR = "127.0.0.1:${toString woodpecker.ports.grpc}";
        WOODPECKER_HOST = "https://${host.serverName}:${toString exposePort}";
      };
    };

    systemd.services.woodpecker-server.serviceConfig = {
      User = "woodpecker";
      Group = "woodpecker";
    };

    services.nginx.virtualHosts.woodpecker = {
      locations."/".proxyPass = "http://${cfg.environment.WOODPECKER_SERVER_ADDR}"; # Default Woodpecker port
      locations."/proto.Woodpecker/" = {
        extraConfig = ''
          grpc_pass grpc://${cfg.environment.WOODPECKER_GRPC_ADDR};
        '';
      };
    };

    services.postgresql = ux.server.ensurePostgresDatabase {name = "woodpecker";};
    systemd.services.woodpecker.after = [config.systemd.services.postgresql.name];
  };
}
# https://www.nemunai.re/post/woodpecker-ci-mixing-http-grpc-on-one-domain-nginx/

