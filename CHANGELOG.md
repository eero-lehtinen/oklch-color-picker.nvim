# Changelog

## [3.4.1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.4.0...v3.4.1) (2025-03-29)


### Bug Fixes

* take into account LSP position encoding ([#35](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/35)) ([3bd4019](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/3bd4019125ce9e7845559fccb09339976e24fb50))

## [3.4.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.3.0...v3.4.0) (2025-03-27)


### Features

* allow enabling all LSPs ([cff1b1d](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/cff1b1daabe1eb9abfd1530f923d2ad9875a0e08))

## [3.3.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.2.0...v3.3.0) (2025-03-26)


### Features

* LSP support ([#32](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/32)) ([f87d7bc](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/f87d7bcb9909f87eb765d7be613478256501b2e0))


### Bug Fixes

* callback from lsp even if all requests fail ([7c21df1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/7c21df1698751197ca0106bc2889c113b66912a2))
* improve logging performance ([a66255a](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/a66255a01c522750d47e927aadac3f018659c8d9))
* LSP overlapping marks ([6e4e12f](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/6e4e12f7892333a7e4a5d7841ca1865a815c1bd5))
* make LSP colors work with 0.10 and simplify code ([3bb9413](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/3bb94137940bbe7d4a009d03852059ffe2d93328))

## [3.2.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.1.0...v3.2.0) (2025-03-18)


### Features

* update picker to 2.1.0 ([#30](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/30)) ([d60e6c1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/d60e6c1ed2a2681b686d741f1e6b876045f5bd69))

## [3.1.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.0.1...v3.1.0) (2025-03-12)


### Features

* update picker version ([af1df5d](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/af1df5d290aaf19ae06cc2be6bf9dbfe1d90e577))


### Bug Fixes

* add extra checks for downloader renames ([8b96e0d](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/8b96e0dcbf5db7b15a270422430628abb59dabb6))
* macos crash by downloading to a temp file (fixes [#27](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/27)) ([05dbe74](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/05dbe747fc031744acac3fc76c1fc1ad5f9cfe4d))

## [3.0.1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.0.0...v3.0.1) (2025-03-11)


### Bug Fixes

* revert picker version ([e414ccb](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/e414ccbcfde65a14ab80501448d4ab21642cf24a))

## [3.0.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v2.0.1...v3.0.0) (2025-03-10)


### ⚠ BREAKING CHANGES

* update picker version to 2.0.0

### Features

* update picker version to 2.0.0 ([cd3798d](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/cd3798df36326732bcba788e3ba136c1161d2f51))

## [2.0.1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v2.0.0...v2.0.1) (2025-03-09)


### Bug Fixes

* allow keeping bold and italic unchanged ([d44318f](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/d44318f5f5c2419a7811ac195da66efaf55c4824))

## [2.0.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v1.3.0...v2.0.0) (2025-03-08)


### ⚠ BREAKING CHANGES

* remove virtual_right style, add more useful styles (fixes #24)

### Features

* remove virtual_right style, add more useful styles (fixes [#24](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/24)) ([a0cc0e7](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/a0cc0e76541747e2e26e25987f43fcdda84ab94f))


### Bug Fixes

* possible infinite hl link chain ([12595cd](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/12595cdc4870080b5b84ce0a53f98d42760178e3))
* use better gravity settings for virtual_left ([d01b692](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/d01b69240e40c13be49992feb0dfeb47062725e6))

## [1.3.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v1.2.2...v1.3.0) (2025-03-07)


### Features

* highlight emphasis for virtual and foreground styles (Closes [#21](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/21)) ([c9f692d](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/c9f692d9aa185d9535142ad291ac7712c62935f2))


### Bug Fixes

* set default hl priority lower than user hl ([762cc68](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/762cc689ed812160be209d2a85652338e2010f40))

## [1.2.2](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v1.2.1...v1.2.2) (2025-03-04)


### Bug Fixes

* update picker to 1.16.1 ([a2f9796](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/a2f97967d1efe07d0f54da533b0ddb14957b0b1e))

## [1.2.1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v1.2.0...v1.2.1) (2025-03-04)


### Bug Fixes

* use nvim data path for binaries ([2e6f35a](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/2e6f35a460230a81abdb68f99e06278894396d7b))

## [1.2.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v1.1.2...v1.2.0) (2025-03-04)


### Features

* update picker app to 0.16.0 ([#17](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/17)) ([59164a3](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/59164a3b1fb13866a387f8850ca2cebcdd0e388a))


### Bug Fixes

* parser version checks on windows ([#15](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/15)) ([c865d83](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/c865d8398c7e4c494b328e4b6aac5a85354e0ca2))

## [1.1.2](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v1.1.1...v1.1.2) (2025-02-18)


### Bug Fixes

* make platform detection more robust ([47f40e7](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/47f40e76a7cbb738a639cb6d1ec2172001501a8c))

## [1.1.1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v1.1.0...v1.1.1) (2025-02-09)


### Bug Fixes

* add color to cmd only if it's set ([#10](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/10)) ([f6a312b](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/f6a312bb20b761735c187dfedc5dc11e43e473e3))

## [1.1.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v1.0.0...v1.1.0) (2025-02-09)


### Features

* open picker without a color under cursor ([#8](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/8)) ([fd096f9](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/fd096f98e5cd35d250b189c8025c5db50dcd3c79)), closes [#6](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/6)

## 1.0.0 (2025-02-09)

Started to use proper semantic versioning and changelog.
