{
  description = "Public homelab NixOS modules and configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    
    # Import sensitive data
    sensitive.url = "github:heymind/sensitive";
    sensitive.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, flake-utils, ... } @ inputs:
  let
    inherit (self) outputs;
    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    
    utils = import ./common/utils.nix { inherit (nixpkgs) lib; };
    inherit (utils) when;

    overlays = import ./overlays { inherit inputs when; };
    
    pkgs = forAllSystems (system:
      (import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      }).appendOverlays [
        overlays.additions
        overlays.unstable-packages
      ]);
  in {
    inherit inputs;
    
    # Export packages and overlays
    packages = forAllSystems (system: (overlays.packages nixpkgs.legacyPackages.${system}));
    overlays = {
      additions = overlays.additions;
      unstable-packages = overlays.unstable-packages;
    };
    
    # NixOS modules for reusable services
    nixosModules = {
      # Base module that defines the sensitive data option
      lib.mySensitive = { lib, ... }: {
        options.my.sensitive.data = lib.mkOption {
          type = lib.types.attrs;
          default = {};
          description = "Sensitive data from external flake";
        };
      };
      
      # Generic modules
      default = import ./modules;
      
      # Installed service modules
      installed = import ./modules/installed;
    };
    
    # NixOS configurations for homelab hosts
    nixosConfigurations = import ./systems { inherit inputs outputs pkgs; sensitive = inputs.sensitive; };
    
    # Utility functions
    lib = utils;
  };
}
