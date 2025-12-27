{
  optimized = {
    # Enable delta: a syntax-highlighting pager for git with side-by-side diffs
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };
  };
  as-heymind = {
    programs.git.settings = {
      userName = "heymind";
      userEmail = "11583541+heymind@users.noreply.github.com";
    };
  };
}
