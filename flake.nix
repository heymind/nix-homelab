{
  description = "Public homelab NixOS modules and configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    
    # Import sensitive data
    sensitive.url = "git+ssh://git@github.com/heymind/sensitive.git";
    sensitive.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... } @ inputs:
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
      }).appendOverlays ([
        overlays.additions
        overlays.unstable-packages
      ] ++ overlays.deploy-rs));
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
      default = import ./modules;
      installed = import ./modules/installed;
    };
    
    # NixOS configurations for homelab hosts
    nixosConfigurations = import ./systems { inherit inputs outputs pkgs; sensitive = inputs.sensitive; };
    
    # Utility functions
    lib = utils;

      deploy = import ./deploy.nix {inherit inputs pkgs;};
  };
}
