{
  sudo-via-touch = {
    security.pam.services.sudo_local.touchIdAuth = true;
  };

  homebrew = {
    nix-homebrew,
    config,
    ...
  }: {
    imports = [
      nix-homebrew.darwinModules.nix-homebrew
    ];
    nix-homebrew = {
      enable = true;
      user = config.system.primaryUser;
    };
  };
}
