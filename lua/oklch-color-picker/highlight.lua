local utils = require 'oklch-color-picker.utils'
local downloader = require 'oklch-color-picker.downloader'

local find, sub, format = string.find, string.sub, string.format
local insert = table.insert
local pow, min, max = math.pow, math.min, math.max
local rshift, band = bit.rshift, bit.band
local nvim_buf_clear_namespace, nvim_buf_set_extmark, nvim_set_hl = vim.api.nvim_buf_clear_namespace, vim.api.nvim_buf_set_extmark, vim.api.nvim_set_hl

local M = {}

---@type fun(color: string, format: string|nil): number|nil
M.parse = nil

---@type oklch.FinalPatternList[]
local patterns = nil

---@type oklch.HightlightConfig
local config = nil

---@type number
local ns
---@type number
local gr

--- @param config_ oklch.HightlightConfig
--- @param patterns_ oklch.FinalPatternList[]
--- @param auto_download boolean
function M.setup(config_, patterns_, auto_download)
  config = config_
  patterns = patterns_

  if M.make_set_extmark() then
    utils.log('Invalid config.highlight.style, highlighting disabled', vim.log.levels.ERROR)
    config.enabled = false
    return
  end

  local on_downloaded = function(err)
    if err then
      utils.log(err, vim.log.levels.ERROR)
      return
    end
    local parser = require('oklch-color-picker.parser').get_parser()
    if parser == nil then
      utils.log("Couldn't load parser library", vim.log.levels.ERROR)
      return
    end
    M.parse = parser.parse

    ns = vim.api.nvim_create_namespace 'OklchColorPickerNamespace'
    gr = vim.api.nvim_create_augroup('OklchColorPicker', {})

    if not config.enabled then
      return
    end

    -- set to false for enable to work
    config.enabled = false
    M.enable()
  end

  if auto_download then
    downloader.ensure_parser_downloaded(vim.schedule_wrap(on_downloaded))
  else
    on_downloaded(nil)
  end
end

function M.disable()
  if not config or not config.enabled then
    return
  end
  config.enabled = false

  M.bufs = {}
  vim.api.nvim_clear_autocmds { group = gr }
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)
    end
  end
end

function M.enable()
  if not M.parse or not config or config.enabled then
    return
  end
  config.enabled = true

  vim.api.nvim_create_autocmd('BufEnter', {
    group = gr,
    callback = function(data)
      M.on_buf_enter(data.buf, false)
    end,
  })

  vim.schedule(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        M.on_buf_enter(bufnr, true)
      end
    end
  end)
end

function M.toggle()
  if config.enabled then
    M.disable()
  else
    M.enable()
  end
end

---@class BufData
---@field pending_updates { from_line: integer, to_line: integer }|nil
---@field prev_view { top: integer, bottom: integer }

--- @type { [integer]: BufData }
M.bufs = {}

--- Unattaching is very annoying, so just make sure we never attach twice
--- @type { [integer]: boolean}
M.buf_attached = {}

--- @param bufnr number
--- @param force_update boolean
function M.on_buf_enter(bufnr, force_update)
  local buftype = vim.api.nvim_get_option_value('buftype', { buf = bufnr })
  if buftype ~= '' then
    return
  end

  if M.bufs[bufnr] then
    if force_update or M.bufs[bufnr].pending_updates then
      M.update(bufnr)
    end
    return
  end

  M.bufs[bufnr] = {
    prev_view = { top = 0, bottom = 0 },
  }

  M.update(bufnr)

  if M.buf_attached[bufnr] == nil then
    vim.api.nvim_buf_attach(bufnr, false, {
      on_bytes = function(_, _, _, start_row, _, _, old_end_row, _, _, new_end_row, _, _)
        if new_end_row < old_end_row then
          -- We deleted some lines.
          -- It's possible that we uncovered new unhighlighted colors from the bottom
          -- of the view, so update the rest of the view.
          M.update_lines(bufnr, start_row, 1e9, false)
        else
          M.update_lines(bufnr, start_row, start_row + new_end_row + 1, false)
        end
      end,
      on_reload = function()
        M.update(bufnr)
      end,
      on_detach = function()
        M.bufs[bufnr] = nil
        M.buf_attached[bufnr] = nil
        vim.api.nvim_clear_autocmds { buffer = bufnr, group = gr }
      end,
    })
    M.buf_attached[bufnr] = true
  end

  vim.api.nvim_create_autocmd('WinScrolled', {
    group = gr,
    buffer = bufnr,
    callback = function(data)
      local buf_data = M.bufs[bufnr]
      if buf_data == nil then
        return
      end

      local top, bottom = M.get_view(bufnr)
      if top < buf_data.prev_view.top and bottom <= buf_data.prev_view.bottom then
        -- scrolled up
        M.update_lines(data.buf, 0, buf_data.prev_view.top + 1, true)
      elseif bottom > buf_data.prev_view.bottom and top >= buf_data.prev_view.top then
        -- scrolled down
        M.update_lines(data.buf, buf_data.prev_view.bottom, 1e9, true)
      else
        -- large jump
        M.update_lines(data.buf, 0, 1e9, true)
      end
      buf_data.prev_view.top = top
      buf_data.prev_view.bottom = bottom
    end,
  })
end

--- @param bufnr integer
function M.update(bufnr)
  M.update_lines(bufnr, 0, 1e9, true)
end

local function get_view()
  return {
    vim.fn.line 'w0' - 1,
    -- return one extra line because it doesn't count it if it's wrapped
    vim.fn.line 'w$' + 1,
  }
end

--- @param bufnr integer
--- @return integer, integer
function M.get_view(bufnr)
  local v = vim.api.nvim_buf_call(bufnr, get_view)
  return v[1], v[2]
end

M.pending_timer = vim.uv.new_timer()

M.perf_logging = false

--- @param bufnr integer
--- @param from_line integer
--- @param to_line integer
--- @param scroll boolean
M.update_lines = vim.schedule_wrap(function(bufnr, from_line, to_line, scroll)
  local buf_data = M.bufs[bufnr]
  if buf_data == nil then
    return
  end

  local top, bottom = M.get_view(bufnr)
  if buf_data.pending_updates == nil then
    buf_data.pending_updates = {
      from_line = max(from_line, top),
      to_line = min(to_line, bottom),
    }
  else
    buf_data.pending_updates.from_line = max(min(buf_data.pending_updates.from_line, from_line), top)
    buf_data.pending_updates.to_line = min(max(buf_data.pending_updates.to_line, to_line), bottom)
  end

  local delay = scroll and config.scroll_delay or config.edit_delay
  M.pending_timer:stop()

  if delay <= 0 then
    M.process_update(bufnr)
    return
  end

  M.pending_timer:start(
    delay,
    0,
    vim.schedule_wrap(function()
      M.process_update(bufnr)
    end)
  )
end)

---@param bufnr integer
function M.process_update(bufnr)
  local buf_data = M.bufs[bufnr]
  if buf_data == nil or buf_data.pending_updates == nil then
    return
  end

  local t = vim.uv.hrtime()

  local from_line = buf_data.pending_updates.from_line --[[@as integer]]
  local to_line = buf_data.pending_updates.to_line --[[@as integer]]
  buf_data.pending_updates = nil

  local lines = vim.api.nvim_buf_get_lines(bufnr, from_line, to_line, false)

  local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

  -- ignore very long lines
  for i, line in ipairs(lines) do
    if string.len(line) > 4000 then
      lines[i] = ''
    end
  end

  M.highlight_lines(bufnr, lines, from_line, ft)

  if M.perf_logging then
    local ms = (vim.uv.hrtime() - t) / 1000000
    print(format('color highlighting took: %.3f ms, lines %d to %d', ms, from_line, to_line))
  end
end

local function to_linear(c)
  if c <= 0.04045 then
    return c / 12.92
  else
    return pow((c + 0.055) / 1.055, 2.4)
  end
end
local linear_lookup = {}
for i = 0, 255 do
  linear_lookup[i] = to_linear(i / 255)
end

--- Follows W3C guidelines in choosing the better contrast foreground.
--- https://stackoverflow.com/questions/3942878/how-to-decide-font-color-in-white-or-black-depending-on-background-color
--- @param rgb number
--- @return boolean
local function is_light(rgb)
  local r = rshift(rgb, 16)
  local g = band(rshift(rgb, 8), 0xff)
  local b = band(rgb, 0xff)
  return 0.2126 * linear_lookup[r] + 0.7152 * linear_lookup[g] + 0.0722 * linear_lookup[b] > 0.179
end

local hex_color_groups = {}

--- @param rgb number
--- @return string
local function compute_color_group(rgb)
  local cached_group_name = hex_color_groups[rgb]
  if cached_group_name ~= nil then
    return cached_group_name
  end

  local hex = format('#%06x', rgb)
  local group_name = format('OCP_%s', sub(hex, 2))

  if config.style == 'background' then
    local opposite = is_light(rgb) and 'Black' or 'White'
    nvim_set_hl(0, group_name, { fg = opposite, bg = hex })
  else
    nvim_set_hl(0, group_name, { fg = hex })
  end

  hex_color_groups[rgb] = group_name

  return group_name
end

---@type fun(integer, integer, integer, integer, string)
local set_extmark

---@return boolean|nil -- true if error
function M.make_set_extmark()
  ---@type vim.api.keyset.set_extmark
  local reuse_mark = {
    priority = config.priority,
  }
  if config.style == 'background' or config.style == 'foreground' then
    set_extmark = function(bufnr, line_n, start_col, end_col, group)
      reuse_mark.hl_group = group
      reuse_mark.end_col = end_col
      nvim_buf_set_extmark(bufnr, ns, line_n, start_col, reuse_mark)
    end
  elseif config.style:find '^virtual' then
    reuse_mark.virt_text = { { config.virtual_text, '' } }
    local virt_arr = reuse_mark.virt_text[1]

    if config.style == 'virtual_left' then
      reuse_mark.virt_text_pos = 'inline'
      set_extmark = function(bufnr, line_n, start_col, _, group)
        virt_arr[2] = group
        nvim_buf_set_extmark(bufnr, ns, line_n, start_col, reuse_mark)
      end
    elseif config.style == 'virtual_right' then
      reuse_mark.virt_text_pos = 'inline'
      set_extmark = function(bufnr, line_n, _, end_col, group)
        virt_arr[2] = group
        nvim_buf_set_extmark(bufnr, ns, line_n, end_col, reuse_mark)
      end
    elseif config.style == 'virtual_eol' then
      set_extmark = function(bufnr, line_n, start_col, _, group)
        virt_arr[2] = group
        nvim_buf_set_extmark(bufnr, ns, line_n, start_col, reuse_mark)
      end
    else
      return true
    end
  else
    return true
  end
end

local ft_patterns_cache = {}

---@param ft string
---@return oklch.FinalPatternList[]
local function get_ft_patterns(ft)
  local ft_patterns = ft_patterns_cache[ft]
  if ft_patterns then
    return ft_patterns
  end

  ft_patterns = {}
  for _, pattern_list in ipairs(patterns) do
    if pattern_list.ft(ft) then
      insert(ft_patterns, pattern_list)
    end
  end
  ft_patterns_cache[ft] = ft_patterns
  return ft_patterns
end

local line_matches = {}

---@param bufnr integer
---@param lines string[]
---@param from_line integer
---@param ft string
function M.highlight_lines(bufnr, lines, from_line, ft)
  local ft_patterns = get_ft_patterns(ft)
  local parse = M.parse

  nvim_buf_clear_namespace(bufnr, ns, from_line, from_line + #lines)

  for i, line in ipairs(lines) do
    local match_idx = 0

    for _, pattern_list in ipairs(ft_patterns) do
      for _, pattern in ipairs(pattern_list) do
        local start = 1
        local match_start, match_end = find(line, pattern.cheap, start)

        while match_start ~= nil do
          local has_space = true
          for m = 1, match_idx, 2 do
            if line_matches[m] <= match_end and line_matches[m + 1] >= match_start then
              has_space = false
              break
            end
          end

          if has_space then
            local replace_start, replace_end
            if pattern.simple_groups then
              replace_start, replace_end = match_start, match_end
            else
              _, _, replace_start, replace_end = find(line, pattern.grouped, match_start)
              replace_end = replace_end - 1
            end

            local color = sub(line, replace_start --[[@as number]], replace_end)
            local rgb = pattern_list.custom_parse and pattern_list.custom_parse(color) or parse(color, pattern_list.format)

            if rgb then
              local group = compute_color_group(rgb)
              local line_n = from_line + i - 1 -- zero based index
              set_extmark(bufnr, line_n, match_start - 1, match_end, group)
            end
            match_idx = match_idx + 2
            line_matches[match_idx - 1] = match_start
            line_matches[match_idx] = match_end
          end

          start = match_end + 1
          match_start, match_end = find(line, pattern.cheap, start)
        end
      end
    end
  end
end

return M
