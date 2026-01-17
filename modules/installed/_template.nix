{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.installed.example; # rename: example -> your service name
  host = config.services.nginx.virtualHosts.example; # ensure host vhost set in the host module
  exposePort = config.services.nginx.defaultSSLListenPort;
  utils = import ./_utils.nix;
in {
  options.installed.example = {
    enable = mkEnableOption "";
    ports = {
      web = mkOption {type = types.int;};
    };
  };

  config = mkIf cfg.enable {
    # Sample service skeleton: replace with real service settings
    services.example = {
      enable = true;
      # config/example options here
      # Example for a web service listening on localhost
      listenAddress = "127.0.0.1";
      port = cfg.ports.web;
    };

    # Nginx reverse proxy to the service
    services.nginx.virtualHosts.example = {
      # serverName is set at host level; we only wire proxy here
      locations."/".proxyPass = "http://127.0.0.1:${toString cfg.ports.web}";
    };

    # Example Postgres database (optional): remove if not needed
    # services.postgresql = ux.server.ensurePostgresDatabase { name = "example"; };

    # Example: open firewall only if binding on non-localhost
    # networking.firewall.allowedTCPPorts = [ cfg.ports.web ];

    # Example: add service dependencies on postgres if enabled
    # systemd.services.example.after = [ config.systemd.services.postgresql.name ];
  };
}
