{
  inputs,
  outputs,
  pkgs,
  sensitive,
  ...
}: let
  inherit (inputs) nixpkgs sops-nix nix-darwin;
  _pkgs = pkgs;
  systemModules = [
    sops-nix.nixosModules.sops
    ../modules
    ../modules/installed
  ];
  utils = import ../common/utils.nix {inherit (nixpkgs) lib;};
  recipes = import ./recipes {inherit (nixpkgs) lib;};
in
  utils.scan ./. ["x86_64-linux"] ({
    system,
    host,
    path,
  }:
    nixpkgs.lib.nixosSystem rec {
      inherit system;
      specialArgs = {
        inherit inputs outputs sops-nix sensitive recipes;
        ux = outputs.utils;
      };
      pkgs = _pkgs.${system};

      modules =
        systemModules
        ++ [
          path
        ];
    })
