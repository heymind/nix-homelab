{
  config,
  lib,
  ...
}:
with lib; let
  jellyfin = config.installed.jellyfin;
in {
  options.installed.jellyfin = {
    enable = mkEnableOption "";
  };
  config = mkIf jellyfin.enable {
    services.jellyfin = {
      enable = true;
    };

    services.nginx.virtualHosts.jellyfin = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8096";
        proxyWebsockets = true;
        recommendedProxySettings = true;
        extraConfig = ''
           add_header X-Content-Type-Options "nosniff";
           add_header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), battery=(), bluetooth=(), camera=(), clipboard-read=(), display-capture=(), document-domain=(), encrypted-media=(), gamepad=(), geolocation=(), gyroscope=(), hid=(), idle-detection=(), interest-cohort=(), keyboard-map=(), local-fonts=(), magnetometer=(), microphone=(), payment=(), publickey-credentials-get=(), serial=(), sync-xhr=(), usb=(), xr-spatial-tracking=()" always;
           add_header Content-Security-Policy "default-src https: data: blob: ; img-src 'self' https://* ; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' https://www.gstatic.com https://www.youtube.com blob:; worker-src 'self' blob:; connect-src 'self'; object-src 'none'; frame-ancestors 'self'; font-src 'self'";

           proxy_buffering off;
        '';
      };
    };
  };
}
