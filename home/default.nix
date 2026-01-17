{
  inputs,
  outputs,
  pkgs,
  sensitive,
  ...
}: let
  inherit (inputs) nixpkgs home-manager sops-nix;
  _pkgs = pkgs;
  commonUtils = import ../common/utils.nix {inherit (nixpkgs) lib;};
  recipes = import ./recipes {inherit (nixpkgs) lib;};
in
  commonUtils.scan ./. ["aarch64-darwin" "x86_64-linux" "aarch64-linux"] ({
    system,
    host,
    path,
  }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = _pkgs.${system};
      extraSpecialArgs = {
        inherit inputs outputs sops-nix sensitive recipes;
        ux = outputs.utils;
      };
      modules = [path];
    })
