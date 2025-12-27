{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.immich;
  immich = config.installed.immich;
  host = config.services.nginx.virtualHosts.immich;
  utils = import ./_utils.nix;
in {
  options.installed.immich = {
    enable = mkEnableOption "";
    ports = {
      web = mkOption {type = types.int;};
    };
    mediaLocation = mkOption {
      type = types.path;
      default = "/var/lib/immich";
      description = "Directory to store media files";
    };
  };

  config = mkIf immich.enable {
    services.immich = {
      enable = true;

      host = "127.0.0.1";
      port = immich.ports.web;
      mediaLocation = immich.mediaLocation;

      # Enable machine learning for face detection and object search
      machine-learning.enable = true;

      # Database configuration
      database = {
        enable = true;
        createDB = true;
        name = "immich";
        user = "immich";
        host = "/run/postgresql";
        enableVectors = false;
        enableVectorChord = true;
      };

      # Redis configuration
      redis = {
        enable = true;
      };

      # Basic settings
      settings = {
        newVersionCheck.enabled = false;
        server.externalDomain = mkIf (host ? serverName) "https://${host.serverName}";
        storageTemplate.enabled = true;
        image.preferEmbeddedPreview = true;
        image.preview.format = "webp";
        image.preview.size = 720;
        facialRecognition.import.enabled = true;
        ffmpeg.transcode = "disabled";
      };
    };

    services.nginx.virtualHosts.immich = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
        extraConfig = ''
          client_max_body_size 50000M;
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
        '';
      };
    };
  };
}
