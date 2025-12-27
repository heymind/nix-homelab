{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.transmission;
  transmission = config.installed.transmission;
in {
  options.installed.transmission = {
    enable = mkEnableOption "";
    ports = {
      web = mkOption {type = types.int;};
    };
    floodUiConfig = mkOption {
      type = types.attrs;
      default = {};
    };
    basicAuthFile = mkOption {type = with types; nullOr str;};
  };
  config = mkIf transmission.enable {
    services.transmission = {
      enable = true;
      webHome = pkgs.unstable.flood-for-transmission.overrideAttrs (oldAttrs: rec {
        installPhase = ''
          runHook preInstall
          cp -r public $out

          ${pkgs.jq}/bin/jq \
            --argjson custom '${builtins.toJSON transmission.floodUiConfig}' \
            '. * $custom' \
            public/config.json.defaults > $out/config.json

          runHook postInstall
        '';
      });

      downloadDirPermissions = "775";
      openPeerPorts = true;
      performanceNetParameters = true;
      settings = {
        rpc-port = transmission.ports.web;
        umask = 0;
        download-dir-permissions = "0777";
        # todo: 优化参数，
        # rpc-bind-address = "0.0.0.0";
        # rpc-whitelist = "127.0.0.*,192.168.124.*";
      };
    };

    services.nginx.virtualHosts.transmission = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.settings.rpc-port}";
        recommendedProxySettings = true;
        basicAuthFile = transmission.basicAuthFile;
      };
    };
  };
}
# rsync -azvP  -e ssh txbj:/srv/data/transmission/git/repositories/ /var/lib/transmission/repositories/
# rsync -azvP  -e ssh txbj:/srv/data/transmission/transmission/ /var/lib/transmission/data/
# ssh txbj 'docker exec txbjng-pg-1  pg_dump -F c -d "postgresql://transmission:transmission@localhost/transmission" ' | sudo -u transmission pg_restore --clean --create -d transmission

