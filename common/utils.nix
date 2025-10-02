{lib, ...}:
with lib; {
  when = cond: value:
    if cond
    then value
    else {};

  scan = path: systems: callback: let
    load-system = system: let
      local-path = path + ("/" + system);
      files = builtins.attrNames (filterAttrs (name: type: type == "regular" && strings.hasSuffix ".nix" name) (builtins.readDir local-path));
      hosts = map (file: substring 0 ((stringLength file) - 4) file) files;
    in
      genAttrs hosts (host:
        callback {
          inherit system host;
          path = path + ("/" + system + "/${host}.nix");
        });
  in
    mergeAttrsList (map load-system systems);
}
