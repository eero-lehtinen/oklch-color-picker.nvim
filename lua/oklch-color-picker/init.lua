local utils = require("oklch-color-picker.utils")
local highlight = require("oklch-color-picker.highlight")
local downloader = require("oklch-color-picker.downloader")
local tailwind = require("oklch-color-picker.tailwind")
local picker = require("oklch-color-picker.picker")

local lshift, band = bit.lshift, bit.band

---@class oklch
local M = {}

---@class oklch.Opts
---@field highlight? oklch.highlight.Opts
---@field patterns? table<string, oklch.PatternList>
---@field register_cmds? boolean
---@field auto_download? boolean Download Rust binaries automatically.
---@field wsl_use_windows_app? boolean Use the Windows version of the app on WSL instead of using unreliable WSLg
---@field log_level? integer

---@class oklch.highlight.Opts
---@field enabled? boolean
---@field edit_delay? number async delay in ms
---@field scroll_delay? number async delay in ms
---@field style? 'background'|'foreground'|'virtual_left'|'virtual_right'|'virtual_eol'
---@field virtual_text? string `● ` also looks nice, nerd fonts also have bigger shapes ` `, `󰝤 `, and ` `
---@field priority? number

---@class oklch.PatternList
---@field priority? number
---@field format? string
---@field ft? string[]
---@field custom_parse? oklch.CustomParseFunc
---@field [integer] string

--- Return a number with R, G, and B components combined into a single number 0xRRGGBB.
--- (`require("oklch-color-picker").components_to_number` can help with this)
--- Return nil for invalid colors.
---@alias oklch.CustomParseFunc fun(match: string): number|nil

---@type oklch.Opts
local default_opts = {

  highlight = {
    enabled = true,
    edit_delay = 60,
    scroll_delay = 0,
    style = "background",
    virtual_text = "■ ",
    priority = 500,
  },

  patterns = {
    hex = { priority = -1, "()#%x%x%x+%f[%W]()" },
    hex_literal = { priority = -1, "()0x%x%x%x%x%x%x+%f[%W]()" },

    css_rgb = { priority = -1, "()rgba?%(.-%)()" },
    css_hsl = { priority = -1, "()hsla?%(.-%)()" },
    css_oklch = { priority = -1, "()oklch%([^,]-%)()" },

    tailwind = {
      priority = -2,
      custom_parse = tailwind.custom_parse,
      "%f[%w][%l%-]-%-()%l-%-%d%d%d?%f[%W]()",
    },

    numbers_in_brackets = { priority = -10, "%(()[%d.,%s]+()%)" },
  },

  register_cmds = true,

  auto_download = true,

  wsl_use_windows_app = true,

  log_level = vim.log.levels.INFO,
}

---@type oklch.Opts
local opts = nil

---@class oklch.FinalPatternList
---@field priority number
---@field name string
---@field format? string
---@field ft fun(ft: string): boolean
---@field custom_parse? oklch.CustomParseFunc
---@field [integer] oklch.FinalPatternListItem

---@class oklch.FinalPatternListItem
---@field cheap string
---@field grouped string
---@field simple_groups boolean

--- @type oklch.FinalPatternList[]
local final_patterns = {}

local empty_group_re = vim.regex([[\(%\)\@<!()]])
assert(empty_group_re)
local unescaped_paren_re = vim.regex([=[\(%\)\@<!\[()\]]=])
assert(unescaped_paren_re)

---@param pattern string
---@return string|nil error
---@return string|nil result
---@return boolean|nil simple_groups
local function validate_and_remove_groups(pattern)
  local m1, m2 = empty_group_re:match_str(pattern)
  if not m1 then
    return "Contains zero empty groups."
  end
  pattern = pattern:sub(1, m1) .. pattern:sub(m2 + 1)
  local m3, m4 = empty_group_re:match_str(pattern)
  if not m3 then
    return "Contains only one empty group."
  end
  pattern = pattern:sub(1, m3) .. pattern:sub(m4 + 1)

  if unescaped_paren_re:match_str(pattern) then
    return "Contains unescaped parentheses in addition to the two empty groups."
  end

  if pattern == "" then
    return "Pattern is empty."
  end

  local simple_groups = m1 == 0 and m4 == string.len(pattern) + 2

  return nil, pattern, simple_groups
end

---@param opts_? oklch.Opts
function M.setup(opts_)
  if vim.fn.has("nvim-0.10") == 0 then
    utils.log("oklch-color-picker.nvim requires Neovim 0.10+", vim.log.levels.ERROR)
    return
  end

  opts = vim.tbl_deep_extend("force", default_opts, opts_ or {})
  utils.setup(opts)

  if opts.register_cmds then
    vim.api.nvim_create_user_command("ColorPickOklch", function()
      picker.pick_under_cursor()
    end, { desc = "Color pick text under cursor with the Oklch color picker" })
  end

  for key, pattern_list in pairs(opts.patterns) do
    if pattern_list and pattern_list[1] ~= nil then
      local ft = function()
        return true
      end
      if pattern_list.ft ~= nil and next(pattern_list.ft) ~= nil then
        local ft_map = {}
        for _, f in ipairs(pattern_list.ft) do
          ft_map[f] = true
        end
        ft = function(filetype)
          return ft_map[filetype] == true
        end
      end

      table.insert(final_patterns, {
        name = key,
        priority = pattern_list.priority or 0,
        format = pattern_list.format,
        ft = ft,
        custom_parse = pattern_list.custom_parse,
      })
      local i = 1
      for j, pattern in ipairs(pattern_list) do
        local err, result, result2 = validate_and_remove_groups(pattern)
        if err then
          utils.report_invalid_pattern(key, j, pattern, err)
        else
          final_patterns[#final_patterns][i] = {
            -- Remove all groups to make scanning faster.
            cheap = assert(result),
            simple_groups = result2 --[[@as boolean]],
            -- Save normal pattern to find replacement positions.
            grouped = pattern,
          }
          i = i + 1
        end
      end
    end
  end

  table.sort(final_patterns, function(a, b)
    return a.priority > b.priority
  end)

  local components_setup = function()
    highlight.setup(opts.highlight, final_patterns, opts.auto_download)
    picker.setup(final_patterns)
  end

  if opts.auto_download then
    downloader.ensure_app_downloaded(function(err)
      if err then
        utils.log(err, vim.log.levels.ERROR)
      else
        components_setup()
      end
    end)
  else
    components_setup()
  end
end

--- Combines r, g, b (0-255) integer values to a combined color 0xRRGGBB.
--- Passing floats or numbers outside of 0-255 can result in weird outputs.
---@param r integer
---@param g integer
---@param b integer
---@return integer
function M.components_to_number(r, g, b)
  return band(lshift(r, 16), lshift(g, 8), b)
end

M.pick_under_cursor = picker.pick_under_cursor
M.open_picker = picker.open_picker

M.highlight = {
  enable = highlight.enable,
  disable = highlight.disable,
  toggle = highlight.toggle,
  set_perf_logging = highlight.set_perf_logging,
  parse = highlight.parse,
}

return M
