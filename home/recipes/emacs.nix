{
  daemon = {...}: {
    services.emacs = {
      enable = true;
      client.enable = true;
    };
  };
  with-plugins = {
    config,
    pkgs,
    ...
  }: let
    package = with pkgs; (
      (emacsPackagesFor emacs-macport).emacsWithPackages (
        epkgs:
          with epkgs; [
            vterm
            # vterm
            # vertico
            # orderless
            # marginalia
            # treemacs
            # treemacs-nerd-icons
            # treemacs-magit
            # rg
            # magit
            # git-timemachine
            # gptel
            # eglot
            # meow

            (treesit-grammars.with-grammars (grammars:
              with grammars; [
                tree-sitter-bash
                tree-sitter-zig
                tree-sitter-yaml
                tree-sitter-vue
                tree-sitter-typescript
                tree-sitter-tsx
                tree-sitter-toml
                tree-sitter-nix
                tree-sitter-markdown
                tree-sitter-markdown-inline
                tree-sitter-lua
                tree-sitter-svelte
                tree-sitter-sql
                tree-sitter-rust
                tree-sitter-python
                tree-sitter-kotlin
                tree-sitter-just
                tree-sitter-json5
                tree-sitter-go
                # tree-sitter-clojure
                tree-sitter-elisp
                tree-sitter-c
                tree-sitter-cpp
              ]))
          ]
      )
    );
  in {
    services.emacs.package = package;
    programs.emacs = {
      enable = true;
      package = package;
    };
    home.packages = [
      pkgs.unstable.macism
    ];
  };

  with-config = {config, ...}: let
    repoRoot = config.my.flakeRepoPath;
    emacsConfigDir = "${repoRoot}/config/emacs";
  in {
    home.file.".emacs.d/init.el".source =
      config.lib.file.mkOutOfStoreSymlink "${emacsConfigDir}/init.el";

    home.file.".emacs.d/early-init.el".source =
      config.lib.file.mkOutOfStoreSymlink "${emacsConfigDir}/early-init.el";

    home.file.".emacs.d/config.org".source =
      config.lib.file.mkOutOfStoreSymlink "${emacsConfigDir}/config.org";
  };
}
