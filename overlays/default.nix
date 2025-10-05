{
  inputs,
  when,
  ...
}: let
  makePackages = import ../pkgs;
in {
  additions = final: prev: (makePackages prev);

  packages = pkgs:
    let
      stdenv = pkgs.stdenv;
    in
    (makePackages pkgs)
    // (
      when stdenv.isDarwin
      {
        # Darwin-specific packages can be added here
      }
    )
    // {
      inherit (pkgs) sops ssh-to-age nix nix-tree deploy-rs;
    };

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
  deploy-rs = import ./deploy-rs.nix {
    inherit (inputs) nixpkgs deploy-rs;
  };


}