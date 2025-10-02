{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  it = config.installed.nginx-sniproxy;
in {
  options.installed.nginx-sniproxy = {
    enable = mkEnableOption "";
    interface = mkOption {
      type = types.str;
      default = "wg0";
    };
    listen = mkOption {type = types.str;};
  };
  config = mkIf it.enable {
    services.nginx.streamConfig = ''
        resolver 8.8.8.8 8.8.4.4 valid=300s;
        preread_buffer_size 16k;
        preread_timeout 30s;
        proxy_buffer_size 64k;
        proxy_connect_timeout 10s;
        proxy_timeout 300s;
        proxy_socket_keepalive on; 
        server {
        isten ${it.listen}:443;


        proxy_buffer_size 1024k;
        ssl_preread on;
        proxy_pass $ssl_preread_server_name:443;
      }
    '';
    
    networking.firewall.interfaces.${it.interface}.allowedTCPPorts = [443];
  };

}
#  ssh txbj 'docker exec txbjng-pg-1  pg_dump -F c -d "postgresql://vaultwarden:vaultwarden@localhost/vaultwarden" ' | sudo -u vaultwarden pg_restore --clean --create -d vaultwarden



