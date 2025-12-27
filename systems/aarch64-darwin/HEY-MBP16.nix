{
  inputs,
  config,
  pkgs,
  lib,
  recipes,
  ...
}: let
  username = "hey";
in {
  imports = with recipes; [
    nix-managed
    nix-optimised

    macos-sudo-via-touch
    macos-homebrew
  ];
  environment.systemPackages = with pkgs.unstable; [
  ];

  homebrew = {
    enable = true;
    casks = [
      "obsidian"
      "ghostty"
      "google-chrome"
      "maczip"
      "qqmusic"
      "microsoft-edge"
      "notion"
      "raycast"
      "steam"
      "telegram-desktop"
      "wechatwebdevtools"
      "zed"
      "iina"
    ];
    onActivation.cleanup = "zap";
  };

  programs.bash.enable = true;
  system.primaryUser = "hey";

  users.users."${username}" = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}
