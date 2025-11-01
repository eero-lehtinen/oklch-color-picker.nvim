# Changelog

## [3.7.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.6.0...v3.7.0) (2025-11-01)


### Features

* Update picker version to 2.3.0 ([cd19a5a](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/cd19a5ae72e1c3fe26551694effb869789ffbf4f))

## [3.6.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.11...v3.6.0) (2025-10-04)


### Features

* **API:** expose current color data under the cursor ([#63](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/63)) ([e6e3e0c](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/e6e3e0c3251f8abc2fe677ec836e742424f79555))

## [3.5.11](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.10...v3.5.11) (2025-09-04)


### Bug Fixes

* add a check for the existence of luajit ([7b98963](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/7b9896322d3ea1c7c800a2af26a6296daa1b881a))

## [3.5.10](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.9...v3.5.10) (2025-09-01)


### Bug Fixes

* add buf loaded checks in async callbacks to avoid errors ([ded99e5](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/ded99e532bea911bd130d04abce1329fd68ba60e))

## [3.5.9](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.8...v3.5.9) (2025-07-29)


### Bug Fixes

* disable builtin lsp colors to avoid conflicts ([cc0b412](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/cc0b41263ac0013c47450aaaa0ed358b1d776a68))

## [3.5.8](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.7...v3.5.8) (2025-07-07)


### Bug Fixes

* respect priority on cached extmarks ([c12febc](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/c12febc153da71bc397b36f631da298a4b6ce967))
* some highlights wrongly staying cached when deleting lines ([473c3e4](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/473c3e4047be437a517de68ae29ea8cb70ada508))

## [3.5.7](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.6...v3.5.7) (2025-07-03)


### Bug Fixes

* lsp deprecation warning in nvim 0.12 ([f3625db](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/f3625db2f3e82bdfe81998be58615309b1c69c77))

## [3.5.6](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.5...v3.5.6) (2025-06-30)


### Bug Fixes

* highlights on files opened at startup ([d428738](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/d428738ea3dda8064ba8d301251ef3824e8c30db))

## [3.5.5](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.4...v3.5.5) (2025-06-30)


### Bug Fixes

* use BufEnter instead of BufWinEnter ([d064ab3](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/d064ab37d46945f0960ee1b1f215c4335f4e4639))

## [3.5.4](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.3...v3.5.4) (2025-06-17)


### Bug Fixes

* avoid errors with invalid buffers ([5e92882](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/5e92882270ef39c358924996648c23d2a121251a))
* do nothing if view hasn't moved ([36310d8](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/36310d857d0012f1f4867fc6fa6853d376cc7f9f))
* use FileType event for initializing highlighting ([6e4ff81](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/6e4ff8158fd1606510cd608a3750e70593623d0b))

## [3.5.3](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.2...v3.5.3) (2025-06-03)


### Bug Fixes

* permission issues in WSL ([b2e7193](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/b2e71937bd2abb1e8ad1b49ce03610ba0918925e))

## [3.5.2](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.1...v3.5.2) (2025-06-03)


### Bug Fixes

* add more logging to downloading and version checks ([1035654](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/1035654f606bf3bbbb27e7c33198083a06fe3a61))

## [3.5.1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.5.0...v3.5.1) (2025-06-01)


### Bug Fixes

* ignore blink cmp menu as it already does colors ([a8bbc95](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/a8bbc95b500c0721d280a48ed45a371bbcc65bf7))
* remove some unnecessary scheduling delays ([98cb083](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/98cb083ac004a72e75258b32f8c846f0cac4e3dd))
* swapping color schemes ([153053a](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/153053add54ab1acd4a24b9ca88021f0caba5a93))

## [3.5.0](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.4.8...v3.5.0) (2025-05-29)


### Features

* update picker to 2.2.1 ([5425f7e](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/5425f7e681baaae221b0c5d0cbafc89687e0e189))


### Bug Fixes

* improve download error messages on windows ([8afef4b](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/8afef4b6c915f1137f21a75dd728fc3a9845dc4a))

## [3.4.8](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.4.7...v3.4.8) (2025-05-21)


### Bug Fixes

* reload colors also on BufRead and VimResized ([5d2099e](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/5d2099e74b5f22c9afdd3c3ccec6c46466a7360e))

## [3.4.7](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.4.6...v3.4.7) (2025-05-21)


### Bug Fixes

* highlighting multiple windows simultaneously ([1a9b3fd](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/1a9b3fde1f740ea7ab85b9ef3e8957faa9fcbf6f))

## [3.4.6](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.4.5...v3.4.6) (2025-05-20)


### Bug Fixes

* ignore only terminal buftype by default ([bc7f652](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/bc7f6523468b3de0f8f1c87fd57bb696db449146))
* use BufNew in addition to BufEnter ([359dd16](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/359dd16289ef2a66bbe20dbe52c34a3df471aabd)), closes [#43](https://github.com/eero-lehtinen/oklch-color-picker.nvim/issues/43)

## [3.4.5](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.4.4...v3.4.5) (2025-04-23)


### Bug Fixes

* lsp color picker replace off by one error ([d13ded9](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/d13ded9db436addf38935ab64bafd39169d2c240))

## [3.4.4](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.4.3...v3.4.4) (2025-04-08)


### Bug Fixes

* include false in pattern type definition ([90b9d9c](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/90b9d9c8115cba9175933e4f1923d70fadf5d176))
* lsp not setting mark end ([4b68fb1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/4b68fb1bb9dd3410c2a18823b682ecf2e5331ad2))


### Performance Improvements

* check file size only on first open ([fe69598](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/fe69598fde4dbc7877c2846d87539e10a1f6ca7d))
* check only active lsp mark positions for current buffer ([afe2aaa](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/afe2aaa9113856186f04550b0ab213b7924ed9c5))
* only check for long lines when opening a file ([a2463c1](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/a2463c1fb9d03f0bbbea22f81613ad7ab978e646))
* reuse highlights when possible ([72f6b3d](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/72f6b3d38e9a6256521c5f8abd97ac0b5a61a070))

## [3.4.3](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.4.2...v3.4.3) (2025-04-01)


### Performance Improvements

* reuse hl group table ([d1f0790](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/d1f07901f0ca942fe29d5aa6576cff05a7b83a25))
* use considerably faster (and undocumented) integer colors in nvim hl ([605309d](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/605309d7e3e2cf630bee90949d86980a8de5ce55))

## [3.4.2](https://github.com/eero-lehtinen/oklch-color-picker.nvim/compare/v3.4.1...v3.4.2) (2025-04-01)


### Performance Improvements

* make overlapping hl check slightly faster and cleaner ([251c48e](https://github.com/eero-lehtinen/oklch-color-picker.nvim/commit/251c48e7cb0c8c8180c1479d62df99b17055d9e2))

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
