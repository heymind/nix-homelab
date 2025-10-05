{
  inputs,
  outputs,
  pkgs,
  sensitive,
  ...
}: let
  inherit (inputs) nixpkgs sops-nix;
  _pkgs = pkgs;
  systemModules = [
    sops-nix.nixosModules.sops
    ../modules
    ../modules/installed
    ./common/ports.nix
  ];
  utils = import ../common/utils.nix {inherit (nixpkgs) lib;};
in
  utils.scan ./. ["x86_64-linux"] ({
    system,
    host,
    path,
  }:
    nixpkgs.lib.nixosSystem rec {
      inherit system;
      specialArgs = {inherit inputs outputs sops-nix sensitive;};
      pkgs = _pkgs.${system};

      modules =
        systemModules
        ++ [
          path
        ];
    })