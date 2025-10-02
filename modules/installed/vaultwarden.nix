{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.vaultwarden;
  vaultwarden = config.installed.vaultwarden;

  host = config.services.nginx.virtualHosts.vaultwarden;
  exposePort = config.services.nginx.defaultSSLListenPort;
  utils = import ./_utils.nix;
in {
  options.installed.vaultwarden = {
    enable = mkEnableOption "";
    ports = {
      web = mkOption {type = types.int;};
    };
  };
  config = mkIf vaultwarden.enable {
    services.vaultwarden = {
      enable = true;
      dbBackend = "postgresql";

      config = {
        DATABASE_URL = "postgres://vaultwarden@/vaultwarden?host=/run/postgresql&sslmode=disable";
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = toString vaultwarden.ports.web;
        DOMAIN = "https://${host.serverName}:${toString exposePort}";
        # - ADMIN_TOKEN=${PWD_ADMIN_TOKEN}
      };
    };

    services.nginx.virtualHosts.vaultwarden = {
      locations."/".proxyPass = "http://127.0.0.1:${toString cfg.config.ROCKET_PORT}"; # Default vaultwarden port
    };

    services.postgresql = utils.ensurePostgresDatabase {name = "vaultwarden";};
    systemd.services.vaultwarden.after = [config.systemd.services.postgresql.name];
  };
}
#  ssh txbj 'docker exec txbjng-pg-1  pg_dump -F c -d "postgresql://vaultwarden:vaultwarden@localhost/vaultwarden" ' | sudo -u vaultwarden pg_restore --clean --create -d vaultwarden

