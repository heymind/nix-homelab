{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  clang,
  pahole,
  bpftools,
  libbpf,
  libffi,
  ...
}:
stdenv.mkDerivation rec {
  pname = "mimic";
  version = "v0.7.0";

  src = fetchFromGitHub {
    owner = "hack3ric";
    repo = "mimic";
    rev = version;
    sha256 = "sha256-wAmz6M7cPRnYz1LzCuYFQQ/Cb+FLh2i8DWpIr61jUMo=";
  };

  nativeBuildInputs = [
    kernel.moduleBuildDependencies
    clang
    pahole
    bpftools
    libbpf
    libffi
  ];

  makeFlags =
    kernel.makeFlags
    ++ [
      "BPFTOOL=${bpftools}/bin/bpftool"
      "SYSTEM_BUILD_DIR=/build/source/system"
      "COMPAT_LINUX_6_1=1"
    ];
  hardeningDisable = [
    "zerocallusedregs"
  ];
  preBuild = ''
    mkdir system
    cp -rL ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/* system/ || true
    cp -rL ${kernel.dev}/vmlinux system/
  '';
  makeTargets = ["build-kmod" "build-cli" "build-tools"];

  installPhase = ''
    mkdir -p $out/lib/modules/${kernel.modDirVersion}/misc
    cp out/mimic.ko  $out/lib/modules/${kernel.modDirVersion}/misc
    install -d $out/bin
    install -Dm755 out/mimic $out/bin/mimic
  '';

  meta = with lib; {
    description = "Intercept and modify HID reports on Linux";
    homepage = "https://github.com/hack3ric/mimic";
    license = licenses.gpl2Plus; # Verify license is still GPLv2+ in the source repo
    maintainers = [maintainers.rencire]; # Keep your maintainer info
    platforms = platforms.linux;
    broken = versionOlder kernel.version "4.14";
  };
}
