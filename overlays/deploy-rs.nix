{
  deploy-rs,
  nixpkgs,
  ...
}: [
  deploy-rs.overlays.default
  (self: super: {
    deploy-rs = {
      inherit (nixpkgs.legacyPackages.${self.system}) deploy-rs;
      lib = super.deploy-rs.lib;
    };
  })
]
