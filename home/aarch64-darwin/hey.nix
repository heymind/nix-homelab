{
  sops-nix,
  recipes,
  pkgs,
  config,
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
      devenv-clojure 
      devenv-python

      hm-my
      hm-common
      hm-sops

      shell-improved
      shell-direnv

      git-optimized
      git-as-heymind

      one2x-claude
      one2x-devenv

      emacs-daemon
      emacs-with-plugins
      emacs-with-config
    ]);

  home.username = "hey";
  home.homeDirectory = "/Users/hey";
  home.stateVersion = "25.11";

  my.flakeRepoPath = "${config.home.homeDirectory}/Workspace/nix-staff/nix-homelab";
  sops.defaultSopsFile = ../../secrets/hey_mbp16.yaml;
}
