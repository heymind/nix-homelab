{
  nix = {pkgs, ...}: {
    home.packages = with pkgs; [
      nixd
      alejandra
    ];
  };
  nodejs = {
    pkgs,
    config,
    ...
  }: {
    home = {
      packages = with pkgs; [nodejs_24 pnpm_10];
      file.".local/share/pnpm/.keep".text = "";
      sessionVariables.PNPM_HOME = "${config.home.homeDirectory}/.local/share/pnpm";
      sessionPath = ["${config.home.homeDirectory}/.local/share/pnpm"];
    };
  };
  bun = {
    pkgs,
    config,
    ...
  }: {
    home = {
      packages = with pkgs; [bun];
      sessionPath = ["${config.home.homeDirectory}/.bun/bin"];
    };
  };
}
