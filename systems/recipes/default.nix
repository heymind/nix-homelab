{lib, ...}: let
  utils = import ../../common/utils.nix {inherit lib;};
in
  utils.loadRecipes2 ./.
