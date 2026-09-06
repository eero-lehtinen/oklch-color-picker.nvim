{ pkgs, pluginSrc }:

pkgs.vimPlugins.oklch-color-picker-nvim.overrideAttrs {
  version = "dev";
  src = pkgs.lib.fileset.toSource {
    root = pluginSrc;
    fileset = pkgs.lib.fileset.unions [
      (pluginSrc + "/lua")
      (pluginSrc + "/doc")
    ];
  };
}