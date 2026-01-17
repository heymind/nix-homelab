{lib, ...}: let
  commonUtils = import ../common/utils.nix {inherit lib;};
in
  commonUtils.loadRecipes2 ./.

