{
  daemon = {...}: {
    services.emacs = {
      enable = true;
      client.enable = true;
    };
  };
  with-plugins = {pkgs, ...}: let package = with pkgs; (
      (emacsPackagesFor emacs-macport).emacsWithPackages (
        epkgs:
          with epkgs; [
            vterm
            vertico
            orderless
            marginalia
            treemacs
            treemacs-nerd-icons
            treemacs-magit
            rg
            magit
            git-timemachine
            gptel
            eglot
            meow

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
                tree-sitter-clojure
                tree-sitter-elisp
                tree-sitter-c
                tree-sitter-cpp
              ]))

            (melpaBuild
              {
                pname = "nano-theme";
                version = "0.3.5";
                src = pkgs.fetchFromGitHub {
                  owner = "rougier";
                  repo = "nano-theme";
                  rev = "41ef36999bacbffe43c4a96320ad6bb285b7f09f";
                  hash = "sha256-dP+PbN6UxJEhiYH+FvMzOtZ6msjDnknF61jlZPGNbHA=";
                };
              })
          ]
      )
    ); in  {
    services.emacs.package = package;
    programs.emacs = {
      enable = true;
      package = package;
    };
  };
}
