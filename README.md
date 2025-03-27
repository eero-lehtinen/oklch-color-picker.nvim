<h1 align="center">oklch-color-picker.nvim</h1>

<p align="center">Sometimes the resolution of a cli just isn't enough</p>

<img src="https://github.com/user-attachments/assets/f4e80185-0f61-4fe5-9f06-1f6dae0ec647" alt="screenshot" width="100%">

## Features

- Select and edit buffer colors in a graphical picker
- Fast async color highlighting
- Supports multiple formats:
  - Hex (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`)
  - CSS (`rgb(..)`, `hsl(..)`, `oklch(..)`)
  - Hex literal (`0xRRGGBB`, `0xAARRGGBB`)
  - Tailwind (e.g. `bg-red-800`)
  - Can recognize any numbers in brackets as a color (e.g., `vec3(0.5, 0.5, 0.5)`)
  - Custom formats can be defined
- LSP colors
- Integrated graphical color picker using the perceptual Oklch color space:
  - Consists of lightness, chroma, and hue for intuitive adjustments
  - Based on [Oklab](https://bottosson.github.io/posts/oklab/) theory, using L<sub>r</sub> as [an improved lightness estimate](https://bottosson.github.io/posts/colorpicker/#intermission---a-new-lightness-estimate-for-oklab)

## Installation

Requires Neovim 0.10+

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "eero-lehtinen/oklch-color-picker.nvim",
  event = "VeryLazy",
  version = "*",
  keys = {
    -- One handed keymap recommended, you will be using the mouse
    {
      "<leader>v",
      function() require("oklch-color-picker").pick_under_cursor() end,
      desc = "Color pick under cursor",
    },
  },
  ---@type oklch.Opts
  opts = {},
}
```

This plugin automatically downloads the picker application and a color parser library from the releases page of [the picker application repository](https://github.com/eero-lehtinen/oklch-color-picker) (it's open source too in a different repo!). The picker is a standalone ⚡Rust⚡ application with ⚡blazing fast⚡ performance and startup time. There are prebuilt binaries for Linux, macOS, and Windows.

## Showcase

### Video

https://github.com/user-attachments/assets/822b5717-133d-4caf-a198-cbe3337bf87a

### LSP features

<img width=550 src="https://github.com/user-attachments/assets/05750119-acc0-4e4e-b923-fe19005bde2f">

## Default Options

```lua
local default_opts = {
  highlight = {
    enabled = true,
    -- Async delay in ms.
    edit_delay = 60,
    -- Async delay in ms.
    scroll_delay = 0,
    -- Options: 'background'|'foreground'|'virtual_left'|'virtual_eol'|'foreground+virtual_left'|'foreground+virtual_eol'
    style = "background",
    bold = false,
    italic = false,
    -- `● ` also looks nice, nerd fonts also have bigger shapes ` `, `󰝤 `, and ` `.
    virtual_text = "■ ",
    -- Less than user hl by default (:help vim.highlight.priorities)
    priority = 175,
    -- Tint the highlight background for 'foreground' and 'virtual' styles when the color is too close to the editor background.
    -- Set `emphasis = false` to disable.
    emphasis = {
      -- Distance (0..1) to the editor background where emphasis activates (first item for dark themes, second for light ones).
      threshold = { 0.1, 0.17 },
      -- How much (0..255) to offset the color (first item for dark colors, second for light ones).
      amount = { 45, -80 },
    },

    -- List of LSP clients that are allowed to highlight colors:
    -- By default, only fairly performant and useful LSPs are enabled.
    -- "tailwindcss", "cssls", and "css_variables" all highlight small files in 2-10ms
    -- (still a lot slower than the 0.1 ms of this plugin, but they give some extra features).
    -- Some LSPs are very slow like "svelte" (>1000 ms) even in tiny files and don't give new features.
    -- "lua_ls" is also not worth enabling because it never finds any colors.
    -- set `enabled_lsps = true` to enable all LSPs anyways.
    enabled_lsps = { "tailwindcss", "cssls", "css_variables" },
    -- Async delay in ms, LSPs also have their own latency.
    lsp_delay = 120,
  },

  patterns = {
    hex = { priority = -1, "()#%x%x%x+%f[%W]()" },
    hex_literal = { priority = -1, "()0x%x%x%x%x%x%x+%f[%W]()" },

    -- Rgb and Hsl support modern and legacy formats:
    -- rgb(10 10 10 / 50%) and rgba(10, 10, 10, 0.5)
    css_rgb = { priority = -1, "()rgba?%(.-%)()" },
    css_hsl = { priority = -1, "()hsla?%(.-%)()" },
    css_oklch = { priority = -1, "()oklch%([^,]-%)()" },

    tailwind = {
      priority = -2,
      custom_parse = tailwind.custom_parse,
      "%f[%w][%l%-]-%-()%l-%-%d%d%d?%f[%W]()",
    },

    -- Allows any digits, dots, commas or whitespace within brackets.
    numbers_in_brackets = { priority = -10, "%(()[%d.,%s]+()%)" },
  },

  register_cmds = true,

  -- Download Rust binaries automatically.
  auto_download = true,

  -- Use the Windows version of the app on WSL instead of using unreliable WSLg.
  wsl_use_windows_app = true,

  log_level = vim.log.levels.INFO,
}
```

## Configuration

### Choose highlighting style:

<img width=600 src="https://github.com/user-attachments/assets/6d4774c6-80a1-46ef-a9cc-f17ae8553c8a">

### Disable default patterns by setting them to false:

```lua
opts = {
  patterns = {
    numbers_in_brackets = false
  }
}
```

### Define your own patterns:

```lua
opts = {
  patterns = {
    -- Example with all properties:
    glsl_vec_linear = {
      -- (Optional) Higher priority patterns are tried first. Defaults to 0.
      priority = 5,
      -- (Optional) Color format for the picker. Auto detect by default.
      format = "raw_rgb_float",
      -- (Optional) Filetypes to apply the pattern to. Must be a table.
      ft = { "glsl" },
      -- (Optional) Custom parser function for unsupported formats.
      custom_parse = function(match)
        -- Some parsing logic ...
        return 0xFFFFFF
      end,
      -- The list of patterns.
      -- Pattern reference at https://www.lua.org/manual/5.4/manual.html#6.4.1
      "vec3%(()[%d.,%s]+()%)", -- Gets `.1,.2,.3` from code `vec3(.1,.2,.3)`
      "vec4%(()[%d.,%s]+()%)",
    },

    -- Replace default css patterns to match only modern formats:
    -- (no "a" suffix in name or commas)
    css_rgb = { "()rgb%([^,]-%)()" },
    css_hsl = { "()hsl%([^,]-%)()" },
  }
}
```

## API & Commands

### Picking

```lua
-- Launch color picker for color under cursor.
require('oklch-color-picker').pick_under_cursor()
-- Force input format, useful for raw color types that can't be auto detected.
require('oklch-color-picker').pick_under_cursor({ force_format = "raw_oklch" })
-- Call `open_picker` as a fallback with default options if there was no color under the cursor.
require('oklch-color-picker').pick_under_cursor({ fallback_open = {} })

-- Open the picker ignoring whatever is under the cursor. Useful for inserting new colors.
require("oklch-color-picker").open_picker()
```

The command `:ColorPickOklch` can be used instead of `pick_under_cursor()`.

#### Definitions

```lua
--- @param opts? picker.PickUnderCursorOpts
--- @return boolean success true if a color was found and picker opened
function pick_under_cursor(opts)

--- @param opts? picker.OpenPickerOpts
--- @return boolean success true if the picker was able to open
function open_picker(opts)

---@class picker.PickUnderCursorOpts
---@field force_format? string auto detect by default
---@field fallback_open? picker.OpenPickerOpts open the picker anyway if no color under the cursor is found

---@class picker.OpenPickerOpts
---@field initial_color? string any color that the picker can parse, e.g. "#fff" (uses a random hex color by default)
---@field force_format? string auto detect by default
```

### Highlighting

```lua
-- Highlighting can be controlled at runtime:
require("oklch-color-picker").highlight.disable()
require("oklch-color-picker").highlight.enable()
require("oklch-color-picker").highlight.toggle()
```

### Color Formats

The picker application supports the following formats: (`hex`, `rgb`, `oklch`, `hsl`, `hex_literal`, `rgb_legacy`, `hsl_legacy`, `raw_rgb`, `raw_rgb_float`, `raw_rgb_linear`, `raw_oklch`).
Most of these are auto detected. E.g. CSS rgb values are detected because they are surrounded by `rgb()` and hex starts with `#`.

The raw formats are just lists of numbers separated by commas that can be used with any programming language. The picker auto detection assumes raw formats to be either integer `0-255` or float `0.0-1.0` srgb colors (formats `raw_rgb` or `raw_rgb_float`). For `raw_rgb_linear` or `raw_oklch` values you have to specify the format manually. Note that the picker accepts colors with and without alpha (3 or 4 numbers separated by commas).

### Patterns

The patterns used are normal lua patterns. They are used to find colors from the buffer text, but they don't need to be exact because validation and parsing is done by the picker application.

CSS colors are mostly already supported, so you should probably only add raw color formats to better support the languages you use. The default `numbers_in_brackets` should already handle most needs, but you can still create your own patterns if you have linear colors or your function names clash with CSS.

The patterns should contain two empty groups `()` to designate the replacement range. E.g. `vec3%(()[%d.,%s]+()%)` will find `.1,.2,.2` from within the text `vec3(.1,.2,.3)`. `[%d.,%s]+` means one or more digits, dots, commas or whitespace characters. Remember to escape literal brackets like this: `%(`.

## Why is the highlighting async and just how fast is it?

I don't like how an insignificant feature like color highlighting can hog CPU resources and cause lag, so this plugin tries to make it fast and unnoticeable. The highlighting is done on a timer after edits to give the immediate CPU time to features you actually care about like Treesitter or LSP. Then after the timer delay has passed, the colors are searched and highlights applied. You can also set the delay to 0 to make highlighting instant.

### Stress testing (2024-11-28)

| Event       | oklch-color-picker.nvim | nvim-colorizer.lua | ccc.nvim | nvim-highlight-colors |
| :---------- | :---------------------- | :----------------- | :------- | :-------------------- |
| BufEnter    | 3 ms                    | 3 ms               | 60 ms    | 10 ms                 |
| WinScrolled | 0.1 – 2 ms              | 0.1 – 2 ms         | n/a      | 10 ms                 |
| TextChanged | 0.1 ms                  | 0.1 ms             | 1.2 ms   | n/a                   |
| InsertLeave | n/a                     | 2 ms               | n/a      | 10 ms                 |

When you open a new buffer, visible lines are processed. With my AMD Ryzen 7 5800X3D, this takes around 0.2 ms on a 65 rows by 120 cols window, full of text and 10 hex colors. In [the stress test file](./stress_test.txt), where the window is filled with ~1000 hex colors, the initial update takes 3 ms, more than half of which is unavoidable Nvim extmark (highlight) creation and assignment overhead.

When scrolling, visible lines are processed but incrementally. If you scroll 10 lines down, only those lines are processed. This means that scrolling between 1 and 65 lines can take 0.1 – 2 ms in the stress test file. Rehighlighting all visible lines takes 2 ms instead of the initial 3 ms because highlight groups are cached. Basically it's faster to see a color for the second time.

When editing, only the changed lines are updated. In the common case, when changing text on a line with no colors, the update takes < 0.01 ms (line being 120 chars wide). Doing the same in the stress test file takes < 0.1 ms. Of course with async, it takes zero time immediately after inserting text.

[NvChad/nvim-colorizer.lua](https://github.com/NvChad/nvim-colorizer.lua) uses the same strategy as this plugin and processes visible lines with incremental scrolling. When opening the stress test file, the update takes 3 ms. Inserting in a line takes 0.1 ms, but it still does a full screen update when leaving insert mode. Features `RGB`, `RRGGBB`, `RRGGBBAA`, `AARRGGBB`, `rgb_fn`, `hsl_fn`, and `tailwind` were enabled.

[uga-rosa/ccc.nvim](https://github.com/uga-rosa/ccc.nvim) instead processes the whole file at startup, then updates only changed lines. The whole stress test file takes 60 ms to process when opening the buffer, scrolling is free and inserting in a single line takes around 1.2 ms. Features `hex`, `hex_short`, `css_rgb`, `css_hsl` and `css_oklch` were enabled.

[brenoprata10/nvim-highlight-colors](https://github.com/brenoprata10/nvim-highlight-colors) in the stress test takes 10 ms to do a full screen update. It doesn't do partial updates, so a full update is done every `InsertLeave` or `WinScrolled` event. The code seems to include handlers for `TextChanged`, but those didn't work for some reason. Features `hex`, `short_hex`, `rgb`, `hsl`, and `tailwind` were enabled.

Measurements were done by manually adding `vim.uv.hrtime` logging to the update functions of each plugin. Check your own timings in this plugin by setting `require("oklch-color-picker").highlight.set_perf_logging(true)` (you can also check your LSP timings with `set_lsp_perf_logging(true)`).

## Other similar plugins

- [KabbAmine/vCoolor.vim](https://github.com/KabbAmine/vCoolor.vim) (Graphical color picker)
- [ziontee113/color-picker.nvim](https://github.com/ziontee113/color-picker.nvim) (TUI color picker)
- [echasnovski/mini.hipatterns](https://github.com/echasnovski/mini.hipatterns) (General async highlighter)
- [My previous attempt (oklch-color-picker-0.nvim)](https://github.com/eero-lehtinen/oklch-color-picker-0.nvim)
