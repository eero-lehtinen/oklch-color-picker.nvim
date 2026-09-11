# Tests

Functional tests for highlighting and the picker, written with
[mini.test](https://github.com/echasnovski/mini.nvim). Each test file drives a
child Neovim over RPC, so the plugin runs with its real module state, extmarks
and autocmds. The whole suite takes about a second.

Requires Neovim 0.12+, git and curl. Run all commands from the repository root.
The NixOS VM test in `nixos/` is separate and has its own README.

## Setup

```sh
nvim --headless -l tests/bootstrap.lua
```

Clones mini.nvim into `tests/.deps/mini.nvim` and downloads the parser library
into `tests/.deps/data`, using the plugin's own downloader and version pin.
Both processes point `XDG_DATA_HOME` there, so the user's data directory is
never touched. Re-run after changing the version in `downloader.lua`.

## Run

```sh
nvim --headless -u tests/minimal_init.lua -c "lua MiniTest.run()"
nvim --headless -u tests/minimal_init.lua -c "lua MiniTest.run_file('tests/test_marks.lua')"
```

Exit code is nonzero on failure. CI runs the same commands on Linux, Windows
and macOS against stable and nightly Neovim.

## Structure

Two kinds of buffers appear in tests:

- Detached: highlighted by calling `highlight_lines` directly. No timers,
  autocmds or view clamping, so results are synchronous and exact. Used for
  mark lifecycle, edits, parsing and styles.
- Live: attached through `init_buf` and shown in a window, with all delays set
  to 0. Tests poll with `vim.wait` until the expected marks appear. Used for
  the LSP path, lifecycle and scrolling.

Marks are compared as `"row:start-end:group"` strings, so a failure prints the
full expected and actual mark lists.

Files:

- `minimal_init.lua`: runtimepath, `XDG_DATA_HOME`, mini.nvim clone. Used by
  the parent and every child.
- `bootstrap.lua`: parser download.
- `helpers.lua`: runs in the parent. Child construction, buffer creation and
  the `expect_*` assertions.
- `child_helpers.lua`: runs in the child as the global `h`. Buffer setup,
  mark inspection, the cache invariant check, an in-process LSP server and a
  `vim.system` stub for the picker.
- `test_marks.lua`, `test_edits.lua`: mark creation, reuse and deletion, the
  per-buffer and per-namespace caches, and marks moved by edits.
- `test_parse.lua`: color formats, default and custom patterns, pattern
  validation.
- `test_style.lua`: extmark shape and highlight group definition per style,
  emphasis.
- `test_lsp.lua`: `textDocument/documentColor` handling with a fake server.
- `test_lifecycle.lua`: enable and disable, ignored filetypes, `ColorScheme`,
  view-based highlighting.
- `test_picker.lua`: color detection under the cursor and applying the
  picker's result, with the app process stubbed.

## Adding a case

Add to the file that matches the area. Prefer a detached buffer; use a live
buffer only when the behavior depends on autocmds or timers. Finish mark tests
with `H.expect_cache_consistent`, which checks that every live mark has a
cache entry and that LSP entries match their mark spans. Files that restart
the child once (`pre_once`) share plugin state between cases, so create a
fresh buffer per case and reset any option you change.
