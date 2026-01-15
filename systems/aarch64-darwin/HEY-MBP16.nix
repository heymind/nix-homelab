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
    python3
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;
  };
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
      "intellij-idea"
    ];
    onActivation.cleanup = "zap";
  };

  programs.bash.enable = true;
  system.primaryUser = "hey";

  system.defaults = {
     NSGlobalDomain.AppleKeyboardUIMode = 3;
     CustomUserPreferences = {
      "com.apple.HIToolbox".AppleGlobalInputSource = false;
     };
  };

  users.users."${username}" = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}
