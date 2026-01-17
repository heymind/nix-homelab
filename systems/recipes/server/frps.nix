{
  defaults = {config, lib, ...}: let
    ports = config.my.ports.frps;
  in {
    services.frp = {
      enable = true;
      role = "server";
      settings = {
        bindAddr = lib.mkDefault "127.0.0.1";
        bindPort = lib.mkDefault ports.web;
        vhostHTTPPort = lib.mkDefault ports.web;

        webServer.addr = lib.mkDefault "127.0.0.1";
        webServer.port = lib.mkDefault ports.dashboard;
        log.level = lib.mkDefault "debug";
        auth.method = lib.mkDefault "token";
        auth.token = lib.mkDefault "{{ .Envs.AUTH_TOKEN }}";
      };
    };

    services.nginx.virtualHosts = {
      frps = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString ports.web}";
          proxyWebsockets = true;
        };
      };
      frps_vhost = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString ports.web}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
    };
  };
}

