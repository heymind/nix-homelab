{
  improved = {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      initContent = ''
        [ -r "$HOME/init.zsh" ] && source "$HOME/init.zsh"
        # compdef _just just
      '';
    };
    programs.starship = {
      enable = true;
      # enableNushellIntegration = true;
      enableZshIntegration = true;
    };
    programs.zoxide = {
      enable = true;
      # enableNushellIntegration = true;
      enableZshIntegration = true;
    };
  };
  direnv = {
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      # enableNushellIntegration = true;
    };
  };
}
