{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  it = config.installed.monitoring;
in {
  options.installed.monitoring = {
    grafana = mkEnableOption "";
    victoriametrics = mkEnableOption "";
    node_exporter = mkEnableOption "";
    vmagent = mkEnableOption "";
    nginx = mkEnableOption "";
    vmagent-remote = mkOption {
      type = types.str;
      default = "";
    };
    ports = {
      grafana = mkOption {type = types.int;};
      victoriametrics = mkOption {type = types.int;};
      node_exporter = mkOption {type = types.int;};
    };
  };

  config = let
    prometheusConfig = {
      scrape_configs = [
        (mkIf it.node_exporter
          {
            job_name = "node";
            metrics_path = "/metrics";
            static_configs = [
              {
                targets = ["127.0.0.1:${toString it.ports.node_exporter}"];
                labels.instance = config.networking.hostName;
              }
            ];
          })
      ];
    };
  in
    mkMerge [
      (mkIf it.grafana {
        services.grafana = {
          enable = true;
          settings = {
            "auth.anonymous".enabled = true;
            "auth.anonymous".org_role = "Viewer";
            auth.disable_login_form = false;
            server.http_port = it.ports.grafana;
          };
          provision = {
            enable = true;
            datasources.settings.datasources = [
              {
                name = "Prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://127.0.0.1:${toString it.ports.victoriametrics}";
                isDefault = true;
              }
            ];

            dashboards.settings.providers = [
              {
                name = "Nodes";
                options.path = ./node-exporter-full.json;
              }
            ];
          };
        };
      })

      (mkIf it.victoriametrics {
        services.victoriametrics = {
          enable = true;
          listenAddress = ":${toString it.ports.victoriametrics}";
          retentionPeriod = "180d";
          inherit prometheusConfig;
        };
      })
      (mkIf it.node_exporter {
        services.prometheus.exporters.node = {
          enable = true;
          port = it.ports.node_exporter;
        };
      })
      (mkIf it.vmagent {
        services.vmagent = {
          enable = true;
          remoteWrite.url = "http://${it.vmagent-remote}:${toString config.installed.monitoring.ports.victoriametrics}/api/v1/write";
          inherit prometheusConfig;
        };
      })
      (mkIf it.nginx {
        services.nginx = {
          additionalModules = with pkgs.nginxModules; [vts sts stream-sts];
          commonHttpConfig = ''vhost_traffic_status_zone;'';
          virtualHosts.vts = {
            listen = [
              {
                addr = "127.0.0.1";
                port = 80;
                ssl = false;
              }
            ];
            locations."/status".extraConfig = ''
              vhost_traffic_status_display;
              vhost_traffic_status_display_format html;
            '';
          };
        };
      })
    ];
}
