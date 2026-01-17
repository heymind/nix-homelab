{ pkgs, ... }:

{
  # nix run '.#deploy:txshhub'
  txshhub = ''
    echo "🚀 Deploying to homelab_txshhub..."
    ${pkgs.deploy-rs.deploy-rs}/bin/deploy -s .#homelab_txshhub -- --option sandbox false "$@"
  '';

  # nix run '.#deploy:box'
  box = ''
    echo "🚀 Deploying to homelab_box..."
    ${pkgs.deploy-rs.deploy-rs}/bin/deploy -s .#homelab_box "$@"
  '';

  # nix run '.#deploy:thunk'
  thunk = ''
    echo "🚀 Deploying to homelab_thunk..."
    ${pkgs.deploy-rs.deploy-rs}/bin/deploy -s .#homelab_thunk "$@"
  '';
}

