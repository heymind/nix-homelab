final:
{
}
// (
  if final.stdenv.isLinux
  then {
    cloudflare-ddns = final.callPackage ./cloudflare-ddns.nix {};
    mimic = final.callPackage ./mimic.nix {
      kernel = final.linuxKernel.packages.linux_xanmod.kernel;
    };
    warpgate = final.callPackage ./warpgate.nix {};
  }
  else {}
)
