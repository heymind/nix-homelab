{
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs) self;
in {
  nodes.homelab_thunk = {
    hostname = "";
    sshUser = "root";
    remoteBuild = true;
    fastConnection = true;

    profiles.system = {
      user = "root";
      path = pkgs.x86_64-linux.deploy-rs.lib.activate.nixos self.nixosConfigurations.homelab_thunk;
    };
  };

  nodes.homelab_box = {
    hostname = "box-local";
    sshUser = "hey";
    remoteBuild = true;
    fastConnection = true;

    profiles.system = {
      user = "root";
      sshUser = "hey";
      path = pkgs.x86_64-linux.deploy-rs.lib.activate.nixos self.nixosConfigurations.homelab_box;
    };
  };

  nodes.homelab_txshhub = {
    hostname = "110.42.214.132";
    sshUser = "root";
    remoteBuild = true;
    fastConnection = false;

    profiles.system = {
      user = "root";
      path = pkgs.x86_64-linux.deploy-rs.lib.activate.nixos self.nixosConfigurations.homelab_txshhub;
    };
  };
}
