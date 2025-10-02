{
  # installed.lldap.ports = {
  #   ldap = 3890;
  #   ldaps = 6360;
  #   web = 22001;
  # };
  # installed.pocket-id.ports = {
  #   backend = 22010;
  #   web = 22011;
  # };
  installed.gitea.ports = {
    web = 22011;
    ssh = 2222;
  };
  installed.woodpecker.ports = {
    web = 22012;
    grpc = 22013;
  };
  installed.frps.ports = {
    web = 22014;
    dashboard = 22015;
  };

  installed.vaultwarden.ports = {
    web = 22016;
  };
  installed.warpgate.ports = {
    web = 22017;
    ssh = 222;
  };
  installed.headscale.ports = {
    web = 22018;
  };
  installed.monitoring.ports = {
    grafana = 22019;
    victoriametrics = 22020;
    node_exporter = 22021;
  };
  installed.transmission.ports = {
    web = 22022;
  };
  installed.aria2.ports = {
    rpc = 22023;
  };
}
