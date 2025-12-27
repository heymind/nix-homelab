{
  lib,
  sensitive,
  ...
}: let
  listenPort = 50281;
  mtu = 1408;

  # Import sensitive data
  wgData = sensitive.data.wireguard or {};
  publicKeys = wgData.publicKeys or {};
  configs = wgData.configs or {};
  nodes = sensitive.data.hosts or {};
in {
  inherit listenPort mtu configs;
  mimic-filters =
    lib.mapAttrs (
      key: config:
        (lib.concatMap (it:
          if it ? Endpoint
          then ["remote=${it.Endpoint}"]
          else [])
        config.peers)
        ++ (
          if nodes.${key}.ip ? v4
          then ["local=${nodes.${key}.ip.v4}:${toString listenPort}"]
          else []
        )
        ++ (
          if nodes.${key}.ip ? v6
          then ["local=${nodes.${key}.ip.v6}:${toString listenPort}"]
          else []
        )
        ++ (
          if config ? filters
          then config.filters
          else []
        )
    )
    configs;
  makeNetdev = key: override: let
    it = configs.${key};
  in
    lib.recursiveUpdate {
      netdevConfig = {
        Kind = "wireguard";
        Name = "wg0";
        MTUBytes = mtu;
      };
      wireguardConfig = {
        ListenPort = listenPort;
        RouteTable = "main";
      };
      wireguardPeers = lib.map (peer:
        peer
        // (let
          keys = lib.attrsets.attrNames (lib.attrsets.filterAttrs (key: pubkey: pubkey == peer.PublicKey) publicKeys);
          key = builtins.elemAt keys 0;
        in {
          PersistentKeepalive =
            if peer ? PersistentKeepalive
            then peer.PersistentKeepalive
            else 7;
          AllowedIPs =
            ["${configs.${key}.address}/32"]
            ++ (
              if peer ? AllowedIPs
              then peer.AllowedIPs
              else []
            );
        }))
      it.peers;
    }
    override;
}
# // (lib.mapAttrs (key: config: {
#     inherit config;
#     mimic-filter = mimic-filters."${key}";
#   })
#   configs)

