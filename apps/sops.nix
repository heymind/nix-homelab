{ pkgs, ... }:

{
  # nix run .#sops:edit -- secrets/xxx.yaml
  edit = ''
    if [ -z "$1" ]; then echo "Usage: nix run .#sops:edit -- <file> [key-path]"; exit 1; fi
    KEY_PATH="''${2:-$HOME/.ssh/id_ed25519}"
    
    if [ ! -f "$KEY_PATH" ]; then
        echo "Error: Key file not found at $KEY_PATH"
        exit 1
    fi

    export SOPS_AGE_KEY=$(${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$KEY_PATH")
    ${pkgs.sops}/bin/sops "$1"
  '';

  # nix run .#sops:keyscan -- <host>
  keyscan = ''
    if [ -z "$1" ]; then echo "Usage: nix run .#sops:keyscan -- <host>"; exit 1; fi
    ${pkgs.openssh}/bin/ssh-keyscan "$1" 2>/dev/null | ${pkgs.ssh-to-age}/bin/ssh-to-age
  '';
}


