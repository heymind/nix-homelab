{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.services.warpgate = {
    enable = mkEnableOption "enable the warpgate service";
    config = mkOption {
      type = lib.types.anything;
      default = {};
    };
    environment = mkOption {
      type = types.attrsOf types.str;
      default = {};
    };
    environmentFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
    };
  };

  config = mkIf config.services.warpgate.enable {
    users.users = {
      warpgate = {
        description = "Warpgate Service";
        home = "/var/lib/warpgate";
        useDefaultShell = true;
        group = "warpgate";
        isSystemUser = true;
      };
    };

    users.groups = {
      warpgate = {};
    };
    environment = {
      systemPackages = [pkgs.warpgate];
      etc."warpgate.yaml" = {
        text = lib.generators.toYAML {} config.services.warpgate.config;
        mode = "0600";
        user = "warpgate";
        group = "warpgate";
      };
    };
    systemd.targets.multi-user.wants = ["warpgate.service"];
    systemd.services."warpgate" = {
      description = "warpgate";
      after = ["network.target"];
      environment = config.services.warpgate.environment;
      serviceConfig = {
        Type = "notify";
        # ExecStart = ''${pkgs.bash}/bin/bash -c "pwd  && echo 1 > 2 && ls -alh . && ${pkgs.strace}/bin/strace  ${warpgatePkg}/bin/warpgate --config /etc/warpgate.yaml run 2>&1"'';
        EnvironmentFile = lib.optional (config.services.warpgate.environmentFile != null) config.services.warpgate.environmentFile;
        ExecStart = ''${pkgs.warpgate}/bin/warpgate --config /etc/warpgate.yaml run'';
        Restart = "on-abnormal";
        CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        ProtectSystem = "strict";
        # ExecStartPre = [V
        #   ''${pkgs.bash}/bin/bash  -c '[ -z "$(ls -A /var/lib/warpgate)" ] && ${warpgatePkg}/bin/warpgate -c $TMPDIR/warpgate.yaml unattended-setup --data-path "/var/lib/warpgate" --http-port 30000 --database-url "${config.services.warpgate.config.database_url}" || true' ''
        # ];
        User = "warpgate";
        Group = "warpgate";
        StateDirectory = "warpgate";
        ConfigurationDirectory = "warpgate";
        RuntimeDirectory = "warpgate";
      };
    };
  };
}
# warpgate -c ./a.yaml  unattended-setup --data-path "/var/lib/warpgate/db" --http-port 30000 --database-url "postgres://warpgate@localhost/warpgate?host=/run/postgresql&sslmode=disable" --admin-password=

