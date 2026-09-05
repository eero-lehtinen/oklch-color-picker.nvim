{ nixpkgs }:

{
  imports = [ (nixpkgs + "/nixos/tests/common/user-account.nix") ];
  services.getty.autologinUser = "alice";
  programs.sway = {
    enable = true;
    xwayland.enable = false;
  };
  environment.variables = {
    SWAYSOCK = "/tmp/sway-ipc.sock";
    WLR_RENDERER = "pixman";
  };
  programs.bash.loginShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      sway
    fi
  '';
  virtualisation.qemu.options = [ "-vga none -device virtio-gpu-pci" ];
}
