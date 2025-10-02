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
# home-manager.lib.homeManagerConfiguration {
#   pkgs = pkgs."${system}";
#   extraSpecialArgs = {inherit inputs;};
#   modules = [path];
# })
# #  {
#   devm = nixpkgs.lib.nixosSystem rec {
#     specialArgs = {inherit inputs outputs sops-nix;};
#     system = "x86_64-linux";
#     pkgs = _pkgs.${system};
#     modules =
#       systemModules
#       ++ [
#         sops-nix.nixosModules.sops
#         ./devm.nix
#       ];
#   };
#   livecd-cn = nixpkgs.lib.nixosSystem rec {
#     specialArgs = {inherit inputs outputs;};
#     system = "x86_64-linux";
#     modules = [
#       ./livecd-cn.nix
#     ];
#   };
#   homelab_txcdhub = nixpkgs.lib.nixosSystem rec {
#     specialArgs = {inherit inputs outputs sops-nix;};
#     system = "x86_64-linux";
#     pkgs = _pkgs.${system};
#     modules =
#       systemModules
#       ++ [
#         sops-nix.nixosModules.sops
#         ./homelab_txcdhub.nix
#       ];
#   };
#   homelab_box = nixpkgs.lib.nixosSystem rec {
#     specialArgs = {inherit inputs outputs sops-nix;};
#     system = "x86_64-linux";
#     pkgs = _pkgs.${system};
#     modules =
#       systemModules
#       ++ [
#         sops-nix.nixosModules.sops
#         ./homelab_box.nix
#       ];
#   };
#   homelab_pcwsl = nixpkgs.lib.nixosSystem rec {
#     specialArgs = {inherit inputs outputs sops-nix;};
#     system = "x86_64-linux";
#     pkgs = _pkgs.${system};
#     modules =
#       systemModules
#       ++ [
#         sops-nix.nixosModules.sops
#         ./homelab_pcwsl.nix
#       ];
#   };
#   homelab_rn0 = nixpkgs.lib.nixosSystem rec {
#     specialArgs = {inherit inputs outputs sops-nix;};
#     system = "x86_64-linux";
#     pkgs = _pkgs.${system};
#     modules =
#       systemModules
#       ++ [
#         sops-nix.nixosModules.sops
#         ./homelab_rn0.nix
#       ];
#   };
#   homelab_ccs0 = nixpkgs.lib.nixosSystem rec {
#     specialArgs = {inherit inputs outputs sops-nix;};
#     system = "x86_64-linux";
#     pkgs = _pkgs.${system};
#     modules =
#       systemModules
#       ++ [
#         sops-nix.nixosModules.sops
#         ./homelab_ccs0.nix
#       ];
#   };
#   prod_txbj = nixpkgs.lib.nixosSystem rec {
#     specialArgs = {inherit inputs outputs sops-nix;};
#     system = "x86_64-linux";
#     pkgs = _pkgs.${system};
#     modules =
#       systemModules
#       ++ [
#         sops-nix.nixosModules.sops
#         ./prod_txbj.nix
#       ];
#   };
#   all = nixpkgs.lib.nixosSystem rec {
#     system = "x86_64-linux";
#     pkgs = _pkgs.${system};
#     modules =
#       systemModules
#       ++ [
#         ({...}: {
#           boot.loader.grub.device = "/dev/vda";
#           fileSystems."/" = {
#             device = "/dev/vda1";
#             fsType = "ext4";
#           };
#         })
#       ];
#   };
# }

