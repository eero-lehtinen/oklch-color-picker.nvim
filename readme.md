<h1 align="center">oklch-color-picker.nvim</h1>

<p align="center">Sometimes the resolution of a cli just isn't enough</p>

<p align="center" width="100%"> 
  <img src="https://github.com/user-attachments/assets/62ed2fb8-fc71-4c7a-9b60-ad7768aabbce" alt="screenshot">
</p>

## Features

- Choose a color from your buffer and edit it in a graphical editor
- Supports many color formats:
  - Hex (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`)
  - Other common CSS formats (`rgb(..)`, `hsl(..)`, `oklch(..)`)
  - Any number in brackets can be detected as a color (e.g. `vec3(0.5, 0.5, 0.5)` or `vec4(0.5, 0.5, 0.5, 1.0)`)
  - You can also define your own formats to have more control
- [The picker application](https://github.com/eero-lehtinen/oklch-color-picker) uses a perceptual colorspace (Oklch) for intuitive editing
  - Consists of lightness, chroma and hue
  - Motivation: [An article by the Oklab creator](https://bottosson.github.io/posts/oklab/)
  - Oklch uses the same theory as Oklab, but uses parameters that are easier to understand
  - L<sub>r</sub> estimate is used instead of L as specified in [another article by the same guy](https://bottosson.github.io/posts/colorpicker/#intermission---a-new-lightness-estimate-for-oklab)

This plugin doesn't highlight any colors in the editor, so a highligher like [uga-rosa/ccc.nvim](https://github.com/uga-rosa/ccc.nvim) or [brenoprata10/nvim-highlight-colors](https://github.com/brenoprata10/nvim-highlight-colors) is a good companion plugin.

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'eero-lehtinen/oklch-color-picker.nvim',
  build = 'download.lua',
  keys = {
    -- One handed keymaps recommended, you will be using the mouse
    { '<leader>v', function() require('oklch-color-picker').pick_under_cursor() end },
  },
  cmd = "ColorPickOklch",
  opts = {}
},
```

You can either include the `build = 'download.lua'` line to download the picker automatically or download it yourself from [the picker application repository](https://github.com/eero-lehtinen/oklch-color-picker) (it's open source too in a different repo!) and put it in your PATH. The picker is a standalone ⚡Rust⚡ application with ⚡blazing fast⚡ performance and startup time.

## Demo

https://github.com/user-attachments/assets/32538f9d-2c49-4729-96a9-3022ce3c851f

## Default Options

```lua
local default_config = {
  log_level = vim.log.levels.INFO,
  patterns = {
    hex = {
      priority = -1,
      '()#%x%x%x%x%x%x%x%x()',
      '()#%x%x%x%x%x%x()',
      '()#%x%x%x%x()',
      '()#%x%x%x()',
    },
    css = {
      priority = -1,
      '()rgb%(.*%)()',
      '()oklch%(.*%)()',
      '()hsl%(.*%)()',
    },
    numbers_in_brackets = {
      priority = -10,
      '%(()[%d.,%s]*()%)',
    },
  },
}
```

## Configuration

Disable default patterns by setting an empty table:

```lua
{
  patterns = {
    css = {}
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
      'vec3%(().*()%)', -- Gets `.1,.2,.3` from code `vec3(.1,.2,.3)`
      'vec4%(().*()%)',
    },
    rust_color = {
      ft = { 'rust' },
      'MyColor::rgb%(().*()%)',
      'Srgba::new%(().*()%)',
    },
    -- You can add as many patterns as you want.
  }
}
```

### Color Formats

The picker application supports the following formats: (`hex`, `rgb`, `oklch`, `hsl`, `raw_rgb`, `raw_rgb_float`, `raw_rgb_linear`, `raw_oklch`).
Most of these are auto detected. The non-raw formats are used in css and easily auto detected because the colors are surrounded by `rgb()` etc.

The raw formats are just lists of numbers separated by commas that can be used with any programming language. The picker auto detection assumes raw formats to be either integer `0-255` or float `0.0-1.0` srgb colors (formats `raw_rgb` or `raw_rgb_float`). For `raw_rgb_linear` or `raw_oklch` values you have to specify the format manually. Note that the picker accepts colors with and without alpha (3 or 4 numbers separated by commas).

### Patterns

The patterns used are normal lua patterns. Css color are mostly already supported, so you should probably only add raw color formats to better support the languages you use.

The default `numbers_in_brackets` should already handle most needs. It matches any number of digits, dots and commas inside brackets. The numbers are validated by the picker application so the pattern doesn't need to specify exact number matching. You can still create your own patterns if you have linear colors that can't be auto detected or if your type names clash with css patterns.

The patterns should contain two empty groups `()` to designate the replacement range. E.g. `vec3%(().*()%)` will find `.1,.2,.2` from within the text `vec3(.1,.2,.3)`. Remember to escape literal brackets `(` with `%`.

## Other similar plugins

- [KabbAmine/vCoolor.vim](https://github.com/KabbAmine/vCoolor.vim)
- [ziontee113/color-picker.nvim](https://github.com/ziontee113/color-picker.nvim)
- [My previous attempt (oklch-color-picker-0.nvim)](https://github.com/eero-lehtinen/oklch-color-picker-0.nvim)
