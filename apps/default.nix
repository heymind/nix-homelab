{ pkgs, lib, ... }:

let
  # 遍历当前目录下的 .nix 文件
  loadApps = dir: let
    # readDir returns an attrset { "filename" = "regular"; "dirname" = "directory"; ... }
    entries = builtins.readDir dir;
    files = lib.filterAttrs (n: v: v == "regular" && n != "default.nix" && lib.hasSuffix ".nix" n) entries;
    
    loadFile = filename: type: let
      category = lib.removeSuffix ".nix" filename; # e.g., "deploy"
      # Import the file, passing pkgs and lib
      recipes = import (dir + "/${filename}") { inherit pkgs lib; };
    in
      # Map { "txshhub" = "script..."; } to { "deploy:txshhub" = { type="app"; ... }; }
      lib.mapAttrs' (name: scriptText: 
        lib.nameValuePair "${category}:${name}" {
          type = "app";
          program = "${pkgs.writeShellScript "${category}-${name}" scriptText}";
        }
      ) recipes;
      
  in
    # Merge all attrsets into one
    lib.foldl' (acc: x: acc // x) {} (lib.mapAttrsToList loadFile files);

in
  loadApps ./.

