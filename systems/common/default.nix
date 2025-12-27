{
  lib,
  inputs,
  config,
  pkgs,
  ...
}: let
  flakeInputs = {inherit (inputs) nixpkgs nixpkgs-unstable;};
in {
  users = lib.mkIf (!(config ? wsl && config.wsl.enable)) {
    users.hey = {
      group = "hey";
      uid = 1000;
      home = "/home/hey";
      createHome = true;
      isNormalUser = true;
      shell = pkgs.zsh;

      extraGroups = ["hey" "wheel"];
    };
    groups.hey = {gid = 1000;};
  };

  environment.systemPackages = with pkgs; [
    ripgrep
    screen
    curl
    wget
    sshpass
    git
    busybox
    iperf
  ];

  security.sudo.wheelNeedsPassword = false;
  programs.neovim = {
    enable = true;
    viAlias = true;
  };

  nix = {
    enable = true;
    channel.enable = false;
    settings = {
      experimental-features = "nix-command flakes";
      nix-path = config.nix.nixPath;
      substituters = [
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        #    "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        #     "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };
}
