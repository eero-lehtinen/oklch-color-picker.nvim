{ nixpkgs, pluginSrc }:

let
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  plugin = import ./plugin.nix { inherit pkgs pluginSrc; };
  neovim = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
    plugins = [ plugin ];
  };
in
pkgs.testers.runNixOSTest {
  name = "oklch-color-picker";

  nodes.machine = {
    imports = [ (nixpkgs + "/nixos/tests/common/x11.nix") ];
    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;
    environment.systemPackages = [ neovim pkgs.xdotool ];
    environment.etc."oklch-smoke.lua".source = ./smoke.lua;
  };

  testScript = ''
    machine.start()
    machine.wait_for_x()
    # The picker must come from the plugin's runtimeDeps, not the system PATH.
    machine.fail("command -v oklch-color-picker")
    try:
        machine.succeed(
            "DISPLAY=:0 LIBGL_ALWAYS_SOFTWARE=1 "
            "nvim --headless -i NONE "
            "-c 'lua dofile(\"/etc/oklch-smoke.lua\")' "
            "> /tmp/oklch-neovim.log 2>&1 &"
        )
        machine.wait_until_succeeds("test -f /tmp/oklch-ready", timeout=60)
        machine.wait_until_succeeds(
            "DISPLAY=:0 xdotool search --onlyvisible --pid "
            "$(pgrep -f '^/nix/store/[^ ]*/bin/oklch-color-picker' | head -n1)",
            timeout=60,
        )
        machine.screenshot("picker-open")
        machine.succeed("test ! -e /root/.local/share/nvim/oklch-color-picker")
    finally:
        machine.execute("cat /tmp/oklch-neovim.log")
        machine.copy_from_machine("/tmp/oklch-neovim.log")
  '';
}
