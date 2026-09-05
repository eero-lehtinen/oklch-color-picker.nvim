# NixOS test

Tests release 5.0.3 with `plugin.nix`: loads the parser, opens the picker in an
X11 and Wayland VMs, and checks that no plugin data directory was created.
`picker.nix` adds the picker's missing X11 runtime libraries.

Run **Actions → NixOS integration test → Run workflow**. Logs and a screenshot
are uploaded as `nixos-test-results-x11` and `nixos-test-results-wayland`. For failures, check `build.log` or
`test.log` before rerunning. The runner needs KVM.

Local run (Linux with Nix and KVM):

```sh
nix-build tests/nixos -A driver \
  --arg nixpkgs /path/to/nixpkgs \
  --arg pluginSrc /path/to/plugin-release \
  --argstr backend x11 \
  --out-link nixos-test-driver
mkdir -p test-results
nixos-test-driver/bin/nixos-test-driver -o "$PWD/test-results"
```
