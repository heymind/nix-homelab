{
  managed = {
    lib,
    config,
    inputs ? {},
    ...
  }: let
    want = ["nixpkgs" "nixpkgs-unstable" "home-manager"];
    flakeInputs = builtins.listToAttrs (builtins.filter (x: x != null) (map (n:
      if builtins.hasAttr n inputs
      then {
        name = n;
        value = inputs.${n};
      }
      else null)
    want));
  in {
    nix = {
      enable = true;
      channel.enable = false;
      settings = {
        experimental-features = "nix-command flakes";
        nix-path = config.nix.nixPath;
      };
      registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
    };
  };

  optimised = {
    nix = {
      gc = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 4;
          Minute = 0;
        }; # 每周日 04:00
        options = "--delete-older-than 14d";
      };

      optimise = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 4;
          Minute = 30;
        };
      };
    };
  };

  ustc-mirror = {
    nix = {
      substituters = [
        "https://mirrors.ustc.edu.cn/nix-channels/store"
      ];
    };
  };
  cachix = {
    nix = {
      substituters = [
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
