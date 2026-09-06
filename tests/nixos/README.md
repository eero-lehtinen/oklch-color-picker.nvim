# NixOS test

Tests the proposed `vimPlugins.oklch-color-picker-nvim` override from the
`oklch-color-picker-nvim-test` branch of the eero-lehtinen/nixpkgs fork, with the
current checkout as the plugin source and no picker on the system PATH. In X11
and Wayland VMs it loads the parser, opens the picker, and checks that no plugin
data directory was created.

Run **Actions → NixOS integration test → Run workflow**. Logs and a screenshot
are uploaded as `nixos-test-results-x11` and `nixos-test-results-wayland`. For
failures, check `build.log` or `test.log` before rerunning. The runner needs KVM.

Local run (Linux with Nix and KVM), from the repository root:

```sh
nix-build tests/nixos -A driver \
  --arg nixpkgs /path/to/nixpkgs \
  --arg pluginSrc ./. \
  --argstr backend x11 \
  --out-link nixos-test-driver
mkdir -p test-results
nixos-test-driver/bin/nixos-test-driver -o "$PWD/test-results"
```