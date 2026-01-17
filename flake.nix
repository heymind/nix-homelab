{
  description = "Public homelab NixOS modules and configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix/a11224af8d824935f363928074b4717ca2e280db";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs-unstable";
    emacs-overlay.inputs.nixpkgs-stable.follows = "nixpkgs";

    # Import sensitive data
    sensitive.url = "git+ssh://git@github.com/heymind/sensitive.git";
    sensitive.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    emacs-overlay,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    commonUtils = import ./common/utils.nix {inherit (nixpkgs) lib;};
    inherit (commonUtils) when;
    utils = import ./utils {inherit (nixpkgs) lib;};

    overlays = import ./overlays {inherit inputs when;};

    pkgs = forAllSystems (system:
      (import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      }).appendOverlays ([
          overlays.additions
          overlays.unstable-packages
          emacs-overlay.overlay
        ]
        ++ overlays.deploy-rs));
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
    nixosConfigurations = import ./systems/nixos.nix {
      inherit inputs outputs pkgs;
      sensitive = inputs.sensitive;
    };
    # sudo nix run .#inputs.nix-darwin.packages.aarch64-darwin.darwin-rebuild -- switch --flake .#HEY-MBP16
    darwinConfigurations = import ./systems/macos.nix {
      inherit inputs outputs pkgs;
      sensitive = inputs.sensitive;
    };

    # Home Manager configurations (auto-discovered from ./home/*.nix)
    # nix run .#inputs.home-manager.packages.aarch64-darwin.home-manager -- switch --flake .#hey
    homeConfigurations = import ./home {
      inherit inputs outputs pkgs;
      sensitive = inputs.sensitive;
    };

    # Utility functions
    lib = commonUtils;
    utils = utils;

    deploy = import ./deploy.nix {inherit inputs pkgs;};

    apps = forAllSystems (system:
      import ./apps {
        pkgs = pkgs.${system};
        inherit (nixpkgs) lib;
      });
  };
}
