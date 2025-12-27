{
  common = {
    home.sessionPath = [
      "$HOME/.local/bin"
    ];

    programs.home-manager.enable = true;
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
