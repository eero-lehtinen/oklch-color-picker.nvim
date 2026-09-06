{ pkgs, pluginSrc }:

pkgs.vimUtils.buildVimPlugin {
  pname = "oklch-color-picker.nvim";
  version = "dev";
  src = pkgs.lib.fileset.toSource {
    root = pluginSrc;
    fileset = pkgs.lib.fileset.unions [
      (pluginSrc + "/lua")
      (pluginSrc + "/doc")
    ];
  };
}