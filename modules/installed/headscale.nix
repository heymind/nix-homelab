{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.headscale;
  headscale = config.installed.headscale;

  ui-version = "2025.03.21";
  ui = builtins.fetchurl {
    name = "ui-${ui-version}.zip";
    url = "https://github.com/gurucomputing/headscale-ui/releases/download/${ui-version}/headscale-ui.zip";
    sha256 = "sha256:1ig99k9q60hngq2bchshy3i54x9d606ayr5in1irdfdls5iyfks6";
  };
  unpacked-ui = pkgs.runCommand "unpack ui" {} ''${pkgs.unzip}/bin/unzip ${ui} -d $out'';

  host = config.services.nginx.virtualHosts.headscale;
  exposePort = config.services.nginx.defaultSSLListenPort;
  utils = import ./_utils.nix;
in {
  options.installed.headscale = {
    enable = mkEnableOption "";
    ports = {
      web = mkOption {type = types.int;};
    };
  };
  config = mkIf headscale.enable {
    services.headscale = {
      enable = true;
      port = headscale.ports.web;
      settings = {
        server_url = "https://${host.serverName}:${toString exposePort}";
        database = {
          type = "postgres";
          postgres = {
            user = "headscale";
            name = "headscale";
            host = "/run/postgresql";
          };
        };
      };
    };
    services.nginx.virtualHosts.headscale = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        proxyWebsockets = true;
      };

      locations."/web" = {
        root = unpacked-ui;
      };
    };

    services.postgresql = utils.ensurePostgresDatabase {name = "headscale";};
    systemd.services.headscale.after = [config.systemd.services.postgresql.name];
  };
}
