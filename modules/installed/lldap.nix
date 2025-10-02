{domain}: {
  config,
  pkgs,
  ...
}: let
  cfg = config.services.lldap;
in {
  services.lldap = {
    enable = true;

    settings = {
      database_url = "postgres://lldap@localhost/lldap?host=/run/postgresql";
      http_url = "https://${domain}";
    };
  };

  services.nginx.virtualHosts.${domain} = {
    locations."/".proxyPass = "http://[::1]:${toString cfg.settings.http_port}";
  };

  services.postgresql = {
    ensureDatabases = ["lldap"];
    ensureUsers = [
      {
        name = "lldap";
        ensureClauses.login = true;
        ensureDBOwnership = true;
      }
    ];
  };
  systemd.services.lldap.after = [config.systemd.services.postgresql.name];
}
