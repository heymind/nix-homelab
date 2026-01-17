{lib, ...}: {
  options.my.ports = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Global port registry shared by recipes/services.";
  };

  config.my.ports = {
    # lldap = {
  #   ldap = 3890;
  #   ldaps = 6360;
  #   web = 22001;
  # };
    # pocket-id = {
  #   backend = 22010;
  #   web = 22011;
  # };
    gitea = {
    web = 22011;
    ssh = 2222;
  };
    woodpecker = {
    web = 22012;
    grpc = 22013;
  };
    frps = {
    web = 22014;
    dashboard = 22015;
  };

    vaultwarden = {
    web = 22016;
  };
    warpgate = {
    web = 22017;
    ssh = 222;
  };
    headscale = {
    web = 22018;
  };
    monitoring = {
    grafana = 22019;
    victoriametrics = 22020;
    node_exporter = 22021;
  };
    transmission = {
    web = 22022;
  };
    aria2 = {
    rpc = 22023;
  };
    openlist = {
    web = 22024;
  };
    immich = {
    web = 22025;
    };
  };
}
