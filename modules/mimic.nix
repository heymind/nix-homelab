{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  serviceConfigOptions = {
    enable = mkEnableOption "the Mimic service on this interface";
    logVerbosity = mkOption {
      type = types.nullOr types.str;
      default = "info";
      description = "Sets log verbosity for this interface.";
      example = "trace";
    };
    linkType = mkOption {
      type = types.nullOr (types.enum ["eth" "none"]);
      default = "eth";
      description = "Specify link layer type for this interface.";
      example = "eth";
    };
    xdpMode = mkOption {
      type = types.nullOr (types.enum ["skb" "native"]);
      default = "native";
      description = "Force XDP attach mode for this interface.";
      example = "skb";
    };
    useLibxdp = mkOption {
      type = types.nullOr types.bool;
      default = false;
      description = "Use libxdp for this interface.";
      example = true;
    };
    maxWindow = mkOption {
      type = types.nullOr types.bool;
      default = false;
      description = "Whether to always use maximum window size for this interface.";
      example = true;
    };
    filters = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Specifies which packets should be processed by Mimic on this interface.";
      example = ["local=192.0.2.1:1234"];
    };
  };
  generateServiceConfig = {...} @ options: ''
    log.verbosity = ${options.logVerbosity}
    link_type = ${options.linkType}
    xdp_mode = ${options.xdpMode}
    ${lib.concatStringsSep "\n" (map (filter: "filter=" + filter) options.filters)}
  '';

  mimicPkg = pkgs.callPackage ../pkgs/mimic.nix {
        kernel = config.boot.kernelPackages.kernel;
      };
in {
  options.services.mimic = {
    enable = mkEnableOption "enable the Mimic service(and kernel module)";
    interfaces = mkOption {
      type = types.attrsOf (types.submodule {options = serviceConfigOptions;});
      default = {};
      description = "Configuration for individual Mimic service instances per network interface.";
    };
  };

  config = mkIf config.services.mimic.enable  {
    boot.extraModulePackages = [mimicPkg];
    environment = {
      systemPackages = [mimicPkg];
      etc =
        mapAttrs' (iface: config: {
          name = "mimic/${iface}.conf";
          value = {text = generateServiceConfig config;};
        })
        config.services.mimic.interfaces;
    };
    systemd.targets.multi-user.wants =
      lib.mapAttrsToList
      (iface: config: "mimic@${iface}.service")
      (
        lib.filterAttrs #
        
        (iface: config: config.enable)
        config.services.mimic.interfaces
      );
    systemd.services."mimic@" = {
      description = "Start Mimic on %i";
      requires = ["modprobe@mimic.service"];
      after = ["network.target"];
      serviceConfig = {
        Type = "notify";
        ExecStart = "${mimicPkg}/bin/mimic run %i -F /etc/mimic/%i.conf";
        Restart = "on-abnormal";
        CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW";
        AmbientCapabilities = "CAP_SYS_ADMIN CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW";
        ProtectSystem = "strict";
        DynamicUser = "yes";
        RuntimeDirectory = "mimic";
      };
    };
  };
}
