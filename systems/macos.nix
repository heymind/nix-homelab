{
  inputs,
  outputs,
  pkgs,
  sensitive,
  ...
}: let
  inherit (inputs) nixpkgs sops-nix nix-darwin nix-homebrew;
  _pkgs = pkgs;
  utils = import ../common/utils.nix {inherit (nixpkgs) lib;};
  recipes = import ./recipes {inherit (nixpkgs) lib;};
in
  utils.scan ./. ["aarch64-darwin"] ({
    system,
    host,
    path,
  }:
    nix-darwin.lib.darwinSystem rec {
      inherit system;
      specialArgs = {inherit inputs outputs sops-nix sensitive recipes nix-homebrew;};
      pkgs = _pkgs.${system};

      modules =
        []
        ++ [
          path
        ];
    })
