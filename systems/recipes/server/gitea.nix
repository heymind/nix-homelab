{
  defaults = {config, lib, ux, ...}: let
    ports = config.my.ports.gitea;
    host = config.services.nginx.virtualHosts.gitea;
    exposePort = config.services.nginx.defaultSSLListenPort;
  in {
    services.gitea = {
      enable = true;
      database = {
        type = "postgres";
        socket = "/run/postgresql";
        name = "gitea";
        user = "gitea";
      };
      settings = {
        server = {
          SSH_PORT = lib.mkDefault ports.ssh;
          SSH_LISTEN_PORT = lib.mkDefault ports.ssh;
          START_SSH_SERVER = lib.mkDefault true;

          HTTP_PORT = lib.mkDefault ports.web;
          HTTP_ADDR = lib.mkDefault "127.0.0.1";
          PROTOCOL = lib.mkDefault "http";

          DOMAIN = lib.mkDefault host.serverName;
          ROOT_URL = lib.mkDefault "https://${host.serverName}:${toString exposePort}";
        };
        service = {
          DISABLE_REGISTRATION = lib.mkDefault true;
        };
      };
    };

    services.nginx.virtualHosts.gitea = {
      locations."/".proxyPass =
        "http://127.0.0.1:${toString config.services.gitea.settings.server.HTTP_PORT}";
    };
    networking.firewall.allowedTCPPorts =
      lib.mkIf config.services.gitea.settings.server.START_SSH_SERVER [ports.ssh];
    services.postgresql = ux.server.ensurePostgresDatabase {name = "gitea";};
    systemd.services.gitea.after = [config.systemd.services.postgresql.name];
  };
}

