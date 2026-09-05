{ pkgs, pluginSrc }:

pkgs.vimPlugins.oklch-color-picker-nvim.overrideAttrs (old: {
  version = "5.0.3";
  src = pluginSrc;

  runtimeDeps = (old.runtimeDeps or [ ]) ++ [ pkgs.oklch-color-picker ];

  postPatch = (old.postPatch or "") + ''
    substituteInPlace lua/oklch-color-picker/init.lua \
      --replace-fail 'auto_download = true,' 'auto_download = false,'
  '';

  postInstall = (old.postInstall or "") + ''
    ln -s \
      ${pkgs.oklch-color-picker}/lib/libparser_lua_module${pkgs.stdenv.hostPlatform.extensions.sharedLibrary} \
      "$target/lua/parser_lua_module.so"
  '';
})
