{ config, lib, pkgs, ... }:
let
  kernelVersion = "6.6.36.6";
  baseKernel = pkgs.linux_6_6;

  src = pkgs.fetchFromGitHub {
    owner = "microsoft";
    repo = "WSL2-Linux-Kernel";
    rev = "linux-msft-wsl-${kernelVersion}";
    sha256 = "sha256-6jLZs+qlmZQHtcG1fmMv9GZsJiqg2EmsiP4QmEaSU2o=";
  };

  extraConfig = with lib.kernel;{
    CONFIG_KERNEL_ZSTD = yes;

    CONFIG_MODULE_COMPRESS_ZSTD = yes;

    CONFIG_ZPOOL = yes;
    CONFIG_ZSWAP = yes;
    CONFIG_ZSWAP_COMPRESSOR_DEFAULT_ZSTD = yes;

    CONFIG_CRYPTO_842 = module;
    CONFIG_CRYPTO_LZ4 = module;
    CONFIG_CRYPTO_LZ4HC = module;
    CONFIG_CRYPTO_ZSTD = yes;

    CONFIG_ZRAM_DEF_COMP_ZSTD = yes;
    CONFIG_ZRAM_WRITEBACK = yes;
    CONFIG_ZRAM_MULTI_COMP = yes;
  };
  configfile =
    let
      # Adapted from https://github.com/tpwrules/nixos-apple-silicon/blob/main/apple-silicon-support/packages/linux-asahi/default.nix
      # Parse CONFIG_<OPT>=[ymn]|"foo" style configuration as found in a config file
      parseLine = (builtins.match ''(CONFIG_[[:upper:][:digit:]_]+)=(([ymn])|"([^"]*)")'');
      tristateMap = with lib.kernel; {
        "y" = yes;
        "m" = module;
        "n" = no;
      };
      # Get either the tristate ([ymn]) option or the freeform ("foo") option
      makeNameValuePair = (match:
        let
          name = (builtins.elemAt match 0);
          tristateValue = (builtins.elemAt match 2);
          freeformValue = (builtins.elemAt match 3);
          value =
            if tristateValue != null then
              tristateMap.${tristateValue}
            else
              lib.kernel.freeform freeformValue;
        in
        lib.nameValuePair name value);
      parseConfig =
        (config:
          let
            lines = lib.strings.splitString "\n" config;
            matches = builtins.filter (match: match != null) (map parseLine lines);
          in
          map makeNameValuePair matches);

      baseConfigfile = "${src}/Microsoft/config-wsl";
      baseConfig = builtins.listToAttrs (parseConfig (builtins.readFile baseConfigfile));
      # Update with extraConfig
      config = baseConfig // extraConfig;
      configAttrToText = (name: value:
        let
          string_value =
            if (builtins.hasAttr "freeform" value) then
              "\"${value.freeform}\""
            else
              value.tristate;
        in
        "${name}=${string_value}"
      );
    in
    pkgs.writeText "config" ''
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList configAttrToText config)}
    '';

  # Adapted from https://github.com/meatcar/wsl2-kernel-nix
  kernelConfig = pkgs.linuxKernel.manualConfig rec {
    inherit configfile src;
    inherit (pkgs) lib;
    inherit (baseKernel) stdenv;

    version = "${kernelVersion}-microsoft-standard-WSL2";
    modDirVersion = version;

    allowImportFromDerivation = true;
  };

  baseKernelPackages = pkgs.linuxPackagesFor kernelConfig;
  kernelPackages = baseKernelPackages.extend (self: super: {
    kernel = super.kernel.overrideAttrs (old: {
      passthru = old.passthru // { inherit (baseKernel) features; };
    });
  });

  # Adapted from nixpkgs/nixos/modules/system/boot/kernel.nix
  # which is not run because NixOS for WSL sets 
  # config.boot.kernel.enable to false
  kernelModulesConf = pkgs.writeText "nixos.conf" ''
    ${lib.concatStringsSep "\n" config.boot.kernelModules}
  '';
in
{
  boot = {
    inherit kernelPackages;
    kernelModules = [ "zram" ];
    modprobeConfig.enable = lib.mkForce true;
    supportedFilesystems = [ "exfat" "zfs" ];
  };
  # Create /etc/modules-load.d/nixos.conf, which is read by
  # systemd-modules-load.service to load required kernel modules.
  environment.etc = { "modules-load.d/nixos.conf".source = kernelModulesConf; };
  system = {
    activationScripts = {
      # Copy the kernel to where it is expected by the WSL configuration
      copyKernel =
        let
          kernelBuildPath = "${config.boot.kernelPackages.kernel}/"
            + "${pkgs.stdenv.hostPlatform.linux-kernel.target}";
          kernelTargetPath = "/mnt/c/Users/hey/WSL/"
            + "${pkgs.stdenv.hostPlatform.linux-kernel.target}";
        in
        ''
          mv -v -f ${kernelTargetPath} ${kernelTargetPath}1
          cp -v ${kernelBuildPath} ${kernelTargetPath}
        '';
    };
    build = with kernelPackages; { inherit kernel; };
    modulesTree = with kernelPackages; [ kernel zfs_2_3 ];
    systemBuilderCommands = ''
      ln -s ${config.system.modulesTree} $out/kernel-modules
    '';
  };
}
# https://github.com/HippocampusGirl/nixos/blob/86f760606f6791c742f2c4654c866788ae899e7f/machines/laptop-wsl/kernel.nix