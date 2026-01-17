{
  defaults = {
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
  };
}

