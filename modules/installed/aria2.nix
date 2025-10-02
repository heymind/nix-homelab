{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.aria2;
  aria2 = config.installed.aria2;
  secret = "aria2-bypass-secret";
  secretb64 = "YXJpYTItYnlwYXNzLXNlY3JldA";
in {
  options.installed.aria2 = {
    enable = mkEnableOption "";
    ports = {
      rpc = mkOption {type = types.int;};
    };
    basicAuthFile = mkOption {type = with types; nullOr str;};
  };
  config = mkIf aria2.enable {
    services.aria2 = {
      enable = true;
      downloadDirPermission = "0775";
      rpcSecretFile = pkgs.writeText "bypass" secret;
      settings = {
        rpc-listen-port = aria2.ports.rpc;
        input-file = "/var/lib/aria2/aria2.session";
        save-session = "/var/lib/aria2/aria2.session";
      };
    };

    services.nginx.virtualHosts.aria2 = {
      basicAuthFile = aria2.basicAuthFile;
      locations."/jsonrpc" = {
        proxyPass = "http://127.0.0.1:${toString cfg.settings.rpc-listen-port}";
        recommendedProxySettings = true;
      };
      locations."= /" = {
        # https://ariang.mayswind.net/command-api.html
        # #!/settings/rpc/set?protocol=${protocol}&host=${rpcHost}&port=${rpcPort}&interface=${rpcInterface}&secret=${secret}
        return = "302 /ariang/#!/settings/rpc/set?protocol=https&host=${config.services.nginx.virtualHosts.aria2.serverName}&port=${toString config.services.nginx.defaultSSLListenPort}&secret=${secretb64}";
      };
      locations."/ariang" = {
        root = "${pkgs.ariang}/share";
      };
    };
  };
}
