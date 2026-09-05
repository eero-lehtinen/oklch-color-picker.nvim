{ pkgs }:

pkgs.oklch-color-picker.overrideAttrs (old: {
  runtimeDependencies = (old.runtimeDependencies or [ ]) ++ (with pkgs; [
    libx11
    libxcursor
    libxi
    libxrandr
    libxcb
  ]);
})
