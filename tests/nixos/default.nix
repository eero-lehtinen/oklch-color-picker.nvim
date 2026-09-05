{ nixpkgs, pluginSrc, backend ? "x11" }:

assert builtins.elem backend [ "x11" "wayland" ];

let
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  plugin = import ./plugin.nix { inherit pkgs pluginSrc; };
  neovim = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
    plugins = [ plugin ];
  };
  launch = pkgs.writeShellScript "oklch-smoke" ''
    export LIBGL_ALWAYS_SOFTWARE=1
    ${if backend == "wayland" then "unset DISPLAY" else "unset WAYLAND_DISPLAY"}
    exec ${neovim}/bin/nvim --headless -i NONE \
      -c 'lua dofile("/etc/oklch-smoke.lua")' > /tmp/oklch-neovim.log 2>&1
  '';
in
pkgs.testers.runNixOSTest {
  name = "oklch-color-picker-${backend}";

  nodes.machine = {
    imports = [
      (if backend == "wayland" then
        import ./wayland.nix { inherit nixpkgs; }
      else
        nixpkgs + "/nixos/tests/common/x11.nix")
    ];
    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;
    environment.systemPackages = [ neovim pkgs.xdotool pkgs.jq ];
    environment.etc."oklch-smoke.lua".source = ./smoke.lua;
  };

  testScript = ''
    machine.start()
    if "${backend}" == "wayland":
        machine.wait_for_file("/tmp/sway-ipc.sock")
    else:
        machine.wait_for_x()
    # The picker must come from the plugin's runtimeDeps, not the system PATH.
    machine.fail("command -v oklch-color-picker")
    try:
        if "${backend}" == "wayland":
            machine.succeed("su - alice -c 'swaymsg exec ${launch}'")
            window_check = "su - alice -c 'swaymsg -t get_tree' | jq -e '.. | objects | select(.name? == \"Oklch Color Picker\" and .shell? == \"xdg_shell\")'"
            data_dir = "/home/alice/.local/share/nvim/oklch-color-picker"
        else:
            machine.succeed("DISPLAY=:0 ${launch} &")
            window_check = "DISPLAY=:0 xdotool search --onlyvisible --name '^Oklch Color Picker$'"
            data_dir = "/root/.local/share/nvim/oklch-color-picker"
        machine.wait_until_succeeds("test -f /tmp/oklch-ready", timeout=60)
        machine.wait_until_succeeds(window_check, timeout=60)
        machine.screenshot("picker-open")
        machine.succeed(f"test ! -e {data_dir}")
    finally:
        machine.execute("cat /tmp/oklch-neovim.log")
        machine.copy_from_machine("/tmp/oklch-neovim.log")
  '';
}
