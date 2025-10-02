{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
  ...
}: let
  inherit (stdenv.hostPlatform) system;
  throwSystem = throw "Unsupported system: ${system}";
  plat =
    {
      x86_64-linux = "x86_64-linux";
      x86_64-darwin = "x86_64-macos";
      aarch64-linux = "arm64-linux";
      aarch64-darwin = "arm64-macos";
    }.${
      system
    } or throwSystem;
  sha256 =
    {
      x86_64-linux = "sha256-a4L8/83wXHKyOZv0wcwznqREqQrp9cUSwJY6UIkozt0=";
      x86_64-darwin = "";
      aarch64-linux = "";
      aarch64-darwin = "";
    }.${
      system
    } or throwSystem;
in
  stdenv.mkDerivation rec {
    pname = "warpgate";
    version = "v0.13.3";

    src = fetchurl {
      name = "warpgate-${version}-${plat}";
      url = "https://github.com/warp-tech/warpgate/releases/download/${version}/warpgate-${version}-${plat}";
      inherit sha256;
    };
    unpackPhase = ":";
    buildInputs = [
      zlib
      stdenv.cc.cc.libgcc or null
    ];
    nativeBuildInputs = [
      autoPatchelfHook
    ];

    sourceRoot = ".";

    installPhase = ''
      install -m755 -D ${src} $out/bin/warpgate
    '';

    meta = with lib; {
      description = "Smart SSH, HTTPS, MySQL and Postgres bastion that requires no additional client-side software";
      homepage = "https://github.com/warp-tech/warpgate";
      license = licenses.gpl2Plus; # Verify license is still GPLv2+ in the source repo
      maintainers = [maintainers.rencire]; # Keep your maintainer info
      platforms = platforms.linux;
    };
  }
