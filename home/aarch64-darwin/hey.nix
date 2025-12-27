{
  sops-nix,
  recipes,
  pkgs,
  ...
}: {
  imports =
    [
      sops-nix.homeManagerModules.sops
    ]
    ++ (with recipes; [
      devenv-nix
      devenv-nodejs
      devenv-bun

      hm-common
      hm-sops

      shell-improved
      shell-direnv

      git-optimized
      git-as-heymind

      one2x-claude

      emacs-daemon
      emacs-with-plugins
    ]);

  home.username = "hey";
  home.homeDirectory = "/Users/hey";
  home.stateVersion = "25.11";
  sops.defaultSopsFile = ../../secrets/hey_mbp16.yaml;
}
