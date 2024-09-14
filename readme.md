# OKLCH Color Picker for Neovim

## Features

- Choose a color from your buffer and edit it in a graphical editor
- Supports many color formats:
  - Hex (`#RRGGBB`, `#RRGGBBAA`)
  - Other common CSS formats (`rgb(..)`, `hsl(..)`, `oklch(..)`)
  - Any number in brackets can be detected as a color (e.g. `vec3(0.5, 0.5, 0.5)` or `vec4(0.5, 0.5, 0.5, 1.0)`)
  - You can also define your own formats to have more control
- The picker application uses the Oklch colorspace
  - Motivation: [An article by the Oklab creator](https://bottosson.github.io/posts/oklab/)
  - Oklch uses the same theory as Oklab, but uses parameters that are easier to understand
  - L<sub>r</sub> estimate is used instead of L as specified in [another article by the same guy](https://bottosson.github.io/posts/colorpicker/#intermission---a-new-lightness-estimate-for-oklab)

This plugin doesn't highlight any colors in the editor, so [brenoprata10/nvim-highlight-colors](https://github.com/brenoprata10/nvim-highlight-colors) is a good companion plugin.

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'eero-lehtinen/oklch-color-picker.nvim',
    build = 'download.lua',
    opts = {}
},
```
You can either include the `build = 'download.lua'` line to download the picker automatically or download it yourself from [Github releases](https://github.com/eero-lehtinen/oklch-color-picker/releases) and put it to your PATH. The picker is a standalone ⚡Rust⚡ application with ⚡blazing fast⚡ hardware acceleration that I molded to fit this use case.

## Usage

Use `:ColorPickOklch` to pick a color under the cursor, or call

```lua
require('oklch-color-picker').pick_under_cursor()
```

Keymaps you have to setup yourself, e.g.

```lua
vim.keymap.set('n', '<leader>p', require('oklch-color-picker').pick_under_cursor)
```

## Default Options

```lua
local default_config = {
    log_level = vim.log.levels.INFO,
    default_patterns = {
        {
            name = "hex",
            "()#%x%x%x%x%x%x%x%x()",
            "()#%x%x%x%x%x%x()",
            "()#%x%x%x%x()",
            "()#%x%x%x()",
        },
        {
            name = "css",
            "()rgb%(.*%)()",
            "()oklch%(.*%)()",
            "()hsl%(.*%)()",
        },
        {
            name = "numbers_in_brackets",
            "%(()[%d.,%s]*()%)",
        },
    },
    disable_default_patterns = {},
    custom_patterns = {},
}
```

## Configuration

List names of default patterns you want to disable:

```lua
disable_default_patterns = { 'numbers_in_brackets' },
```

Define your own patterns:

```lua
custom_patterns = {
    {
        -- (Optional) Used in possible error messages with invalid patterns
        name = 'glsl_linear',
        -- (Optional) Often useless because the picker application detects formats automatically.
        format = 'raw_rgb_linear',
        -- (Optional) Filetypes to apply the pattern to. Must be a table.
        ft = { 'glsl' },
        -- The list of patterns.
        'vec3%(().*()%)', -- Gets `.1,.2,.3` from code `vec3(.1,.2,.3)`
        'vec4%(().*()%)',
    },
    {
        name = 'my_rust_color',
        format = 'raw_rgb',
        ft = { 'rust' },
        'MyColor::rgb%(().*()%)',
        'Srgba::new%(().*()%)',
    },
    -- You can have as many patterns as you want.
    -- They are ordered and the first one that matches is used.
    {
      -- ...
    },
},
```

### Color Formats

The picker application supports the following formats: (`hex`, `rgb`, `oklch`, `hsl`, `raw_rgb`, `raw_rgb_float`, `raw_rgb_linear`, `raw_oklch`).
Most of these are auto detected. The non-raw formats are used in css and easily automatically detected because the colors are surrounded by recognisable `rgb()` or similar.

The raw formats are just lists of "raw" numbers that can be used with any programming language. The picker assumes raw formats to be either integer `0-255` or float `0.0-1.0` srgba colors (formats `raw_rgb` or `raw_rgb_float`). For raw linear or raw oklch values you have to specify the format manually.

### Patterns

The patterns used are normal lua patterns. Css color are mostly already supported, so you should probably only add raw color formats to better support the languages you use. The default `numbers_in_brackets` should already handle most needs, but if you have linear colors, you have to specify new ones yourself.

The patterns should contain two empty groups `()` to designate the replacement range. E.g. `vec3%(().*()%)` will find `1.,2.,3.` from within the text `vec3(1.,2.,3.)`, which is correct. The pattern doesn't need to be too accurate with the digits because the picker handles the validation and quickly responds if the color is invalid. It doesn't care if there are commas or invalid characters within the match, the numbers will be extracted out. Finally, remember to escape literal brackets `(` with `%`.

## Other similar plugins

- [KabbAmine/vCoolor.vim](https://github.com/KabbAmine/vCoolor.vim)
- [ziontee113/color-picker.nvim](https://github.com/ziontee113/color-picker.nvim)
