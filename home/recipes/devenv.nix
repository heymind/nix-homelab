{
  nix = {pkgs, ...}: {
    home.packages = with pkgs; [
      nixd
      alejandra
    ];
  };
  python = {pkgs,config,...}:{
    home = {
      packages = with pkgs; [python3 uv];
    };
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
  clojure = {pkgs, ...}: {
    home = {
      packages = with pkgs; [
        (clojure.override { jdk = javaPackages.compiler.temurin-bin.jdk-21; })
        javaPackages.compiler.temurin-bin.jdk-21
        clojure-lsp
        clj-kondo
        cljfmt
        cljstyle
        babashka
        bbin
      ];
      sessionVariables = {
        JAVA_HOME = "${pkgs.javaPackages.compiler.temurin-bin.jdk-21}";
      };
    };
  };
}
