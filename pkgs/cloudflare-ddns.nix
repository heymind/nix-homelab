{
  lib,
  stdenv,
  makeWrapper,
  bash,
  curl,
  bind,        # provides dig
  iproute2,    # provides ip command (Linux)
  gnugrep,     # provides grep
  gawk,        # provides awk
  coreutils,   # provides cut, head, etc.
  ...
}:
stdenv.mkDerivation rec {
  pname = "cloudflare-ddns";
  version = "1.0.0";

  src = ../scripts/cloudflare-ddns.bash;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    mkdir -p $out/bin
    cp ${src} $out/bin/cloudflare-ddns
    chmod +x $out/bin/cloudflare-ddns

    # Wrap the script to ensure all dependencies are in PATH
    wrapProgram $out/bin/cloudflare-ddns \
      --prefix PATH : ${lib.makeBinPath [
        bash
        curl
        bind       # dig
        iproute2   # ip
        gnugrep    # grep
        gawk       # awk
        coreutils  # cut, head, etc.
      ]}
  '';

  meta = with lib; {
    description = "Cloudflare DDNS updater script";
    homepage = "https://github.com/yourusername/nix-homelab";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "cloudflare-ddns";
  };
}

