local utils = require 'oklch-color-picker.utils'
local highlight = require 'oklch-color-picker.highlight'
local downloader = require 'oklch-color-picker.downloader'
local tailwind = require 'oklch-color-picker.tailwind'

local lshift, band = bit.lshift, bit.band

---@class oklch
local M = {}

--- Return a number with R, G, and B components combined into a single number 0xRRGGBB.
--- (`require("oklch-color-picker").components_to_number` can help with this)
--- Return nil for invalid colors.
---@alias oklch.CustomParseFunc fun(match: string): number|nil

---@alias oklch.PatternList { priority: number|nil, format: string|nil, ft: string[]|nil, custom_parse: oklch.CustomParseFunc|nil , [number]: string }

---@class oklch.Config
local default_config = {

  ---@class oklch.HightlightConfig
  highlight = {
    enabled = true,
    -- async delay in ms
    edit_delay = 60,
    -- async delay in ms
    scroll_delay = 0,
    ---@type 'background'|'foreground'|'virtual_left'|'virtual_right'|'virtual_eol'
    style = 'background',
    -- '■ ' also looks nice (remove space with monospace nerd symbols)
    virtual_text = '● ',
    priority = 500,
  },

  ---@type { [string]: oklch.PatternList}
  patterns = {
    hex = { priority = -1, '()#%x%x%x+%f[%W]()' },
    hex_literal = { priority = -1, '()0x%x%x%x%x%x%x+%f[%W]()' },

    -- Rgb and Hsl support modern and legacy formats:
    -- rgb(10 10 10 / 50%) and rgba(10, 10, 10, 0.5)
    css_rgb = { priority = -1, '()rgba?%(.-%)()' },
    css_hsl = { priority = -1, '()hsla?%(.-%)()' },
    css_oklch = { priority = -1, '()oklch%([^,]-%)()' },

    tailwind = {
      priority = -2,
      custom_parse = tailwind.custom_parse,
      '%f[%w][%l%-]-%-()%l-%-%d%d%d?%f[%W]()',
    },

    -- Allows any digits, dots, commas or whitespace within brackets.
    numbers_in_brackets = { priority = -10, '%(()[%d.,%s]+()%)' },
  },

  register_cmds = true,

  -- Download Rust binaries automatically.
  auto_download = true,

  log_level = vim.log.levels.INFO,
}

---@type oklch.Config
M.config = nil

---@alias oklch.FinalPatternList { priority: number, name: string, format: string|nil, ft: (fun(ft: string): boolean), custom_parse: oklch.CustomParseFunc|nil, [number]: { cheap: string, grouped: string, simple_groups: boolean } }

--- @type oklch.FinalPatternList[]
M.final_patterns = {}

---@param config? oklch.Config
function M.setup(config)
  M.config = vim.tbl_deep_extend('force', default_config, config or {})
  utils.setup(M.config)

  if M.config.register_cmds then
    vim.api.nvim_create_user_command('ColorPickOklch', function()
      M.pick_under_cursor()
    end, { desc = 'Color pick text under cursor with the Oklch color picker' })
  end

  for key, pattern_list in pairs(M.config.patterns) do
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

      table.insert(M.final_patterns, {
        name = key,
        priority = pattern_list.priority or 0,
        format = pattern_list.format,
        ft = ft,
        custom_parse = pattern_list.custom_parse,
      })
      local i = 1
      for j, pattern in ipairs(pattern_list) do
        local err, result, result2 = M.validate_and_remove_groups(pattern)
        if err then
          utils.report_invalid_pattern(key, j, pattern, err)
        else
          M.final_patterns[#M.final_patterns][i] = {
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

  table.sort(M.final_patterns, function(a, b)
    return a.priority > b.priority
  end)

  if M.config.auto_download then
    downloader.ensure_app_downloaded(function(err)
      if err then
        utils.log(err, vim.log.levels.ERROR)
      else
        highlight.setup(M.config.highlight, M.final_patterns, M.config.auto_download)
      end
    end)
  else
    highlight.setup(M.config.highlight, M.final_patterns, M.config.auto_download)
  end
end

local empty_group_re = vim.regex [[\(%\)\@<!()]]
assert(empty_group_re)
local unescaped_paren_re = vim.regex [=[\(%\)\@<!\[()\]]=]
assert(unescaped_paren_re)

---@param pattern string
---@return string|nil error
---@return string|nil result
---@return boolean|nil simple_groups
function M.validate_and_remove_groups(pattern)
  local m1, m2 = empty_group_re:match_str(pattern)
  if not m1 then
    return 'Contains zero empty groups.'
  end
  pattern = pattern:sub(1, m1) .. pattern:sub(m2 + 1)
  local m3, m4 = empty_group_re:match_str(pattern)
  if not m3 then
    return 'Contains only one empty group.'
  end
  pattern = pattern:sub(1, m3) .. pattern:sub(m4 + 1)

  if unescaped_paren_re:match_str(pattern) then
    return 'Contains unescaped parentheses in addition to the two empty groups.'
  end

  if pattern == '' then
    return 'Pattern is empty.'
  end

  local simple_groups = m1 == 0 and m4 == string.len(pattern) + 2

  return nil, pattern, simple_groups
end

--- @alias oklch.PendingEdit { bufnr: number, changedtick: number, line_number: number, start: number, finish: number, color: string, color_format: string|nil }|nil

--- @type oklch.PendingEdit
local pending_edit = nil

---@param color string
local function apply_new_color(color)
  if not pending_edit then
    utils.log("Don't call apply_new_color if there is no pending edit!!!", vim.log.levels.DEBUG)
    return
  end

  vim.schedule(function()
    if pending_edit.changedtick ~= vim.api.nvim_buf_get_changedtick(pending_edit.bufnr) then
      utils.log(string.format("Not applying new color '%s' because the buffer has changed", color), vim.log.levels.WARN)
      return
    end

    vim.api.nvim_buf_set_text(
      pending_edit.bufnr,
      pending_edit.line_number - 1,
      pending_edit.start - 1,
      pending_edit.line_number - 1,
      pending_edit.finish,
      { color }
    )
    pending_edit = nil

    utils.log("Applied '" .. color .. "'", vim.log.levels.INFO)
  end)
end

local function start_app()
  if not pending_edit then
    utils.log("Can't start app, no pending edit", vim.log.levels.WARN)
    return
  end

  local stdout = function(err, data)
    if data then
      utils.log('Stdout: ' .. data, vim.log.levels.DEBUG)
      if data == '' then
        utils.log('Picker returned an empty string', vim.log.levels.WARN)
        return
      end
      local color = data:match '^[^\r\n]*'
      apply_new_color(color)
    elseif err then
      utils.log('Stdout error: ' .. err, vim.log.levels.DEBUG)
    else
      utils.log('Stdout closed', vim.log.levels.DEBUG)
    end
  end

  local stderr = function(err, data)
    if data then
      utils.log(data:match '^[^\r\n]*', vim.log.levels.WARN)
    elseif err then
      utils.log('Stderr error: ' .. err, vim.log.levels.DEBUG)
    else
      utils.log('Stderr closed', vim.log.levels.DEBUG)
    end
  end

  local exec = utils.executable_full_path()
  if exec == nil then
    utils.log('Picker executable not found', vim.log.levels.ERROR)
    return
  end

  local cmd = { exec, pending_edit.color }
  if pending_edit.color_format then
    table.insert(cmd, '--format')
    table.insert(cmd, pending_edit.color_format)
  end

  vim.system(cmd, { stdout = stdout, stderr = stderr }, function(res)
    if res.code ~= 0 then
      utils.log('App failed and exited with code ' .. res.code, vim.log.levels.DEBUG)
    end
    utils.log('App exited successfully ' .. vim.inspect(res), vim.log.levels.DEBUG)
  end)
end

--- @param line string
--- @param cursor_col number
--- @param ft string
--- @return { pos: [number, number], color: string, color_format: string|nil }| nil
local function find_color(line, cursor_col, ft)
  for _, pattern_list in ipairs(M.final_patterns) do
    if pattern_list.ft(ft) then
      for _, pattern in ipairs(pattern_list) do
        local start = 1
        local match_start, match_end, replace_start, replace_end = line:find(pattern.grouped, start)
        while match_start ~= nil do
          if cursor_col >= match_start and cursor_col <= match_end then
            local replace = line:sub(replace_start --[[@as number]], replace_end - 1)
            local format = pattern_list.format
            local color
            if pattern_list.custom_parse then
              local rgb = pattern_list.custom_parse(replace)
              color = rgb and string.format('#%06x', rgb) or nil
              format = nil
            else
              color = replace
            end

            if color then
              return {
                pos = { replace_start, replace_end - 1 },
                color = color,
                color_format = format,
              }
            end
          end
          start = match_end + 1
          match_start, match_end, replace_start, replace_end = line:find(pattern.grouped, start)
        end
      end
    end
  end

  return nil
end

--- @param force_color_format string|nil
function M.pick_under_cursor(force_color_format)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2] + 1

  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  local ft = vim.api.nvim_get_option_value('filetype', { buf = 0 })

  local res = find_color(line, col, ft)

  if not res then
    utils.log('No color under cursor', vim.log.levels.INFO)
    return
  end

  utils.log(string.format("Found color '%s' at position %s", res.color, vim.inspect(res.pos)), vim.log.levels.DEBUG)

  pending_edit = {
    bufnr = bufnr,
    changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
    line_number = row,
    start = res.pos[1],
    finish = res.pos[2],
    color = res.color,
    color_format = force_color_format or res.color_format,
  }

  start_app()
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

return M
