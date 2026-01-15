{
  common = {
    home.sessionPath = [
      "$HOME/.local/bin"
    ];

    programs.home-manager.enable = true;
  };

  my = {
    lib,
    config,
    ...
  }: {
    options.my.flakeRepoPath = lib.mkOption {
      type = lib.types.str;
      default = null;
      example = "/Users/hey/Workspace/nix-staff/nix-homelab";
      description = "Absolute path to the local nix-homelab flake checkout (used for out-of-store symlinks).";
    };

    config = {
      assertions = [
        {
          assertion = (lib.isString config.my.flakeRepoPath) && (config.my.flakeRepoPath != "");
          message = "Please set `my.flakeRepoPath` to an absolute path of your local nix-homelab checkout.";
        }
      ];
    };
  };

  sops = {
    config,
    pkgs,
    ...
  }: {
    sops = {
      age.sshKeyPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];
    };
    home = {
      packages = with pkgs; [ssh-to-age];
      file.".local/bin/sops" = {
        text = ''
          #!/usr/bin/env bash
          export SOPS_AGE_KEY=$(ssh-to-age -private-key -i ~/.ssh/id_ed25519)
          exec ${pkgs.sops}/bin/sops "$@"
        '';
        executable = true;
      };
    };
  };
}
