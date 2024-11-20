<h1 align="center">oklch-color-picker.nvim</h1>

<p align="center">Sometimes the resolution of a cli just isn't enough</p>

<p align="center" width="100%"> 
  <img src="https://github.com/user-attachments/assets/8b6b8e8a-1b5a-4ea8-b4cb-0df8dc2d7377" alt="screenshot">
</p>

## Features

- Select and edit buffer colors in a graphical picker
- Fast async color highlighting
- Supports multiple formats:
  - Hex (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`), CSS (`rgb(..)`, `hsl(..)`, `oklch(..)`)
  - Can recognize any numbers in brackets as a color (e.g., `vec3(0.5, 0.5, 0.5)`)
  - Custom formats can be defined
- Integrated graphical [color picker](https://github.com/eero-lehtinen/oklch-color-picker) using the perceptual Oklch color space:
  - Consists of lightness, chroma, and hue for intuitive adjustments
  - Based on [Oklab](https://bottosson.github.io/posts/oklab/) theory, using L<sub>r</sub> as [an improved lightness estimate](https://bottosson.github.io/posts/colorpicker/#intermission---a-new-lightness-estimate-for-oklab)

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'eero-lehtinen/oklch-color-picker.nvim',
  config = function()
    require('oklch-color-picker').setup {}
    -- One handed keymaps recommended, you will be using the mouse
    vim.keymap.set('n', '<leader>v', '<cmd>ColorPickOklch<cr>')
  end,
},
```

This plugin automatically downloads the picker application and a color parser library from the releases page of [the picker application repository](https://github.com/eero-lehtinen/oklch-color-picker) (it's open source too in a different repo!). The picker is a standalone ⚡Rust⚡ application with ⚡blazing fast⚡ performance and startup time.

## Demo

https://github.com/user-attachments/assets/a6df331c-10dc-4e50-8f89-bc4ab191de57

## Default Options

```lua
local default_config = {
  patterns = {
    hex = {
      priority = -1,
      '()#%x%x%x+%f[%W]()',
    },
    css = {
      priority = -1,
      -- Rgb and Hsl support modern and legacy formats:
      -- rgb(10 10 10 / 50%) and rgba(10, 10, 10, 0.5)
      -- `-` is the same as `*`, but matches the shortest possible sequence.
      '()rgba?%(.-%)()',
      '()hsla?%(.-%)()',
      '()oklch%(.-%)()',
    },
    numbers_in_brackets = {
      priority = -10,
      -- Allows any digits, dots, commas or whitespace within brackets.
      '%(()[%d.,%s]+()%)',
    },
  },
  highlight = {
    enabled = true,
    edit_delay = 60,
    scroll_delay = 0,
  },
  log_level = vim.log.levels.INFO,
  -- Download Rust binaries automatically.
  auto_download = true,
}
```

## Configuration

Disable default patterns by setting them to false:

```lua
{
  patterns = {
    numbers_in_brackets = false
  }
}
```

Define your own patterns:

```lua
{
  patterns = {
    glsl_vec_linear = {
      -- (Optional) Higher priority patterns are tried first. Defaults to 0.
      priority = 5,
      -- (Optional) Color format for the picker. Auto detect by default.
      format = 'raw_rgb_linear',
      -- (Optional) Filetypes to apply the pattern to. Must be a table.
      ft = { 'glsl' },
      -- The list of patterns.
      'vec3%(()[%d.,%s]+()%)', -- Gets `.1,.2,.3` from code `vec3(.1,.2,.3)`
      'vec4%(()[%d.,%s]+()%)',
    },
    rust_color = {
      ft = { 'rust' },
      'MyColor::rgb%(()[%d.,%s]+()%)',
      'Srgba::new%(()[%d.,%s]+()%)',
    },
    -- You can add as many patterns as you want.
  }
}
```

Highlighting can be controlled at runtime:

```lua
require("oklch-color-picker.highlight").disable()
require("oklch-color-picker.highlight").enable()
require("oklch-color-picker.highlight").toggle()
```

### Color Formats

The picker application supports the following formats: (`hex`, `rgb`, `oklch`, `hsl`, `raw_rgb`, `raw_rgb_float`, `raw_rgb_linear`, `raw_oklch`).
Most of these are auto detected. The non-raw formats are used in CSS and easily auto detected because the colors are surrounded by `rgb()` etc.

The raw formats are just lists of numbers separated by commas that can be used with any programming language. The picker auto detection assumes raw formats to be either integer `0-255` or float `0.0-1.0` srgb colors (formats `raw_rgb` or `raw_rgb_float`). For `raw_rgb_linear` or `raw_oklch` values you have to specify the format manually. Note that the picker accepts colors with and without alpha (3 or 4 numbers separated by commas).

### Patterns

The patterns used are normal lua patterns. CSS colors are mostly already supported, so you should probably only add raw color formats to better support the languages you use.

The default `numbers_in_brackets` should already handle most needs. It matches any number of digits, dots and commas inside brackets. The numbers are validated by the picker application so the pattern doesn't need to specify exact number matching. You can still create your own patterns if you have linear colors that can't be auto detected.

The patterns should contain two empty groups `()` to designate the replacement range. E.g. `vec3%(()[%d.,%s]+()%)` will find `.1,.2,.2` from within the text `vec3(.1,.2,.3)`. `[%d.,%s]+` means one or more digits, dots, commas or whitespace characters. Remember to escape literal brackets like this: `%(`.

## Why is the highlighting async and just how fast is it?

I don't like how an insignificant feature like color highlighting can hog CPU resources and cause lag, so this plugin tries to make it fast and unnoticeable. The highlighting is done on a timer after edits to give the immediate CPU time to features you actually care about like Treesitter or LSP. Then after the timer delay has passed, the colors are searched and highlights applied. You can also set the delay to 0 to make highlighting instant.

When you open a new buffer, visible lines are processed. With my AMD Ryzen 7 5800X3D, this takes around 0.2 ms on a 65 rows by 120 cols window, full of text and 10 hex colors. In [the stress test file](./stress_test.txt), where the window is filled with ~1000 hex colors, the initial update takes 4 ms, more than half of which is unavoidable Nvim extmark (highlight) creation and assignment overhead.

When scrolling, visible lines are processed but incrementally. I you scroll 10 lines down, only those lines are processed. This means that scrolling between 1 and 65 lines can take 0.1 – 2 ms in the stress test file.

When editing, only the changed lines are updated. In the common case, when changing text on a line with no colors, the update takes < 0.01 ms (line being 120 chars wide). Doing the same in the stress test file takes < 0.1 ms. Of course with async, it takes zero time immediately after inserting text.

[NvChad/nvim-colorizer.lua](https://github.com/NvChad/nvim-colorizer.lua) uses the same strategy as this plugin and prcesses visible lines with incremental scrolling. When opening the stress test file, the update takes 3 ms. Inserting in a line takes 0.2 ms, but it still does a full screen update when leaving insert mode. Only `hex`, `rgb`, and `hsl` features were enabled to make things more fair.

[uga-rosa/ccc.nvim](https://github.com/uga-rosa/ccc.nvim) instead processes the whole file at startup, then updates only changed lines. The whole stress test file takes 50 ms to process when opening the buffer, scrolling is free and inserting in a single line takes around 0.9 ms. Only `hex`, `rgb`, `hsl` and `oklch` features were enabled.

[brenoprata10/nvim-highlight-colors](https://github.com/brenoprata10/nvim-highlight-colors) in the stress test takes 10 ms to do a full screen update. It doesn't do partial updates, so a full update is done every `InsertLeave` or `WinScrolled` event. The code seems to include handlers for `TextChanged`, but those didn't work for some reason. Only `hex`, `rgb` and `hsl` features were enabled.

Measurements were done by manually adding `vim.uv.hrtime` logging to the update functions of each plugin. Check your own timings in this plugin by setting `require("oklch-color-picker.highlight").perf_logging = true`.

### Stress test results (2024-11-15)

| Event       | oklch-color-picker.nvim | nvim-colorizer.lua | ccc.nvim | nvim-highlight-colors |
| :---------- | :---------------------- | :----------------- | :------- | :-------------------- |
| BufEnter    | 3 ms                    | 3 ms               | 50 ms    | 10 ms                 |
| WinScrolled | 0.1 ms – 2 ms           | 0.2 – 2 ms         | n/a      | 10 ms                 |
| TextChanged | 0.1 ms                  | 0.2 ms             | 0.9 ms   | n/a                   |
| InsertLeave | n/a                     | 2 ms               | n/a      | 10 ms                 |

## Other similar plugins

- [KabbAmine/vCoolor.vim](https://github.com/KabbAmine/vCoolor.vim) (Graphical color picker)
- [ziontee113/color-picker.nvim](https://github.com/ziontee113/color-picker.nvim) (TUI color picker)
- [echasnovski/mini.hipatterns](https://github.com/echasnovski/mini.hipatterns) (General async highlighter)
- [My previous attempt (oklch-color-picker-0.nvim)](https://github.com/eero-lehtinen/oklch-color-picker-0.nvim)
