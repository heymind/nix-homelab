let
  dirEntries = builtins.readDir ./.;

  filteredEntries = builtins.filter (
    name:
      !(builtins.substring 0 1 name == "_") && name != "default.nix"
  ) (builtins.attrNames dirEntries);

  imports =
    builtins.map (
      name: let
        entry = dirEntries.${name};
      in
        if entry == "directory"
        then ./. + "/${name}/default.nix"
        else if (builtins.substring (builtins.stringLength name - 4) 4 name) == ".nix"
        then ./. + "/${name}"
        else null
    )
    filteredEntries;

  validImports = builtins.filter (x: x != null) imports;
in {
  imports = validImports;
}
