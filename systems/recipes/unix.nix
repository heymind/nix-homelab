{
  cli-common = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      git
      wget
      curl
      screen
    ];
  };

  cli-modern-alts = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      ripgrep
      fd
    ];
  };
}
