{ pkgs, pluginSrc }:

pkgs.vimPlugins.oklch-color-picker-nvim.overrideAttrs {
  version = "5.0.3";
  src = pluginSrc;
}
