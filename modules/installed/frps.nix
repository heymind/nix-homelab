{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.frp;
  frps = config.installed.frps;
in {
  options.installed.frps = {
    enable = mkEnableOption "";
    ports = {
      web = mkOption {type = types.int;};
      dashboard = mkOption {type = types.int;};
    };
  };
  config = mkIf frps.enable {
    services.frp = {
      enable = true;

      role = "server";

      settings = {
        bindAddr = "127.0.0.1";
        bindPort = frps.ports.web;
        #tls.force = false
        vhostHTTPPort = frps.ports.web;

        webServer.addr = "127.0.0.1";
        webServer.port = frps.ports.dashboard;
        # webServer.user = "admin"
        # webServer.password = "admin"
        log.level = "debug";
        auth.method = "token";
        auth.token = "{{ .Envs.AUTH_TOKEN }}";
      };
    };

    services.nginx.virtualHosts = {
      frps = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString frps.ports.web}";
          proxyWebsockets = true;
        };
      };
      frps_vhost = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString frps.ports.web}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
    };
  };
}
