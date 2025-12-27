{lib, ...}:
with lib; let
  nixFilesIn = {
    dir,
    skipDefault ? true,
    skipUnderscore ? false,
  }: let
    entries = builtins.readDir dir;
  in
    builtins.sort builtins.lessThan
    (builtins.filter
      (name:
        entries.${name}
        == "regular"
        && (!skipDefault || name != "default.nix")
        && (!skipUnderscore || !(strings.hasPrefix "_" name))
        && builtins.match ".*\\.nix" name != null)
      (builtins.attrNames entries));

  basenamesFromNixFiles = files:
    map (file: substring 0 ((stringLength file) - 4) file) files;
in {
  when = cond: value:
    if cond
    then value
    else {};

  # Load all *.nix files (except default.nix) from a directory, and flatten
  # each file's attrset exports into `${basename}-${key}`.
  #
  # Example:
  #   ./foo.nix => { bar = ...; baz = ...; }
  # becomes:
  #   { "foo-bar" = ...; "foo-baz" = ...; }
  loadRecipes = dir: let
    nixFiles = nixFilesIn {
      dir = dir;
      skipDefault = true;
      skipUnderscore = false;
    };

    loadFile = file: let
      basename = builtins.substring 0 (builtins.stringLength file - 4) file; # drop ".nix"
      defs = import (dir + "/${file}");
    in
      builtins.listToAttrs (map (k: {
        name = "${basename}-${k}";
        value = defs.${k};
      }) (builtins.attrNames defs));
  in
    builtins.foldl' (acc: x: acc // x) {} (map loadFile nixFiles);

  scan = path: systems: callback: let
    load-system = system: let
      local-path = path + ("/" + system);
      nixFiles = nixFilesIn {
        dir = local-path;
        skipDefault = true;
        skipUnderscore = false;
      };
      hosts = basenamesFromNixFiles nixFiles;
    in
      genAttrs hosts (host:
        callback {
          inherit system host;
          path = path + ("/" + system + "/${host}.nix");
        });
  in
    mergeAttrsList (map load-system systems);
}
