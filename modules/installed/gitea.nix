{
  config,
  lib,
  ux,
  ...
}:
with lib; let
  cfg = config.services.gitea;
  gitea = config.installed.gitea;
  host = config.services.nginx.virtualHosts.gitea;
  exposePort = config.services.nginx.defaultSSLListenPort;
in {
  options.installed.gitea = {
    enable = mkEnableOption "";
    ports = {
      web = mkOption {type = types.int;};
      ssh = mkOption {type = types.int;};
    };
  };
  config = mkIf gitea.enable {
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
          SSH_PORT = gitea.ports.ssh;
          SSH_LISTEN_PORT = gitea.ports.ssh;
          START_SSH_SERVER = true;

          HTTP_PORT = gitea.ports.web;
          HTTP_ADDR = "127.0.0.1";
          PROTOCOL = "http";

          DOMAIN = host.serverName;
          ROOT_URL = "https://${host.serverName}:${toString exposePort}";
        };
        service = {
          DISABLE_REGISTRATION = true;
        };
      };
    };

    services.nginx.virtualHosts.gitea = {
      locations."/".proxyPass = "http://127.0.0.1:${toString cfg.settings.server.HTTP_PORT}";
    };
    networking.firewall.allowedTCPPorts = mkIf cfg.settings.server.START_SSH_SERVER [gitea.ports.ssh];
    services.postgresql = ux.server.ensurePostgresDatabase {name = "gitea";};
    systemd.services.gitea.after = [config.systemd.services.postgresql.name];
  };
}
# rsync -azvP  -e ssh txbj:/srv/data/gitea/git/repositories/ /var/lib/gitea/repositories/
# rsync -azvP  -e ssh txbj:/srv/data/gitea/gitea/ /var/lib/gitea/data/
# ssh txbj 'docker exec txbjng-pg-1  pg_dump -F c -d "postgresql://gitea:gitea@localhost/gitea" ' | sudo -u gitea pg_restore --clean --create -d gitea

