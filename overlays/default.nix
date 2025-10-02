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
      # Common packages
      sops = pkgs.sops;
      ssh-to-age = pkgs.ssh-to-age;
      nix = pkgs.nix;
      nix-tree = pkgs.nix-tree;
    };

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}