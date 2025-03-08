local utils = require("oklch-color-picker.utils")
local downloader = require("oklch-color-picker.downloader")

local find, sub, format = string.find, string.sub, string.format
local insert = table.insert
local pow, min, max = math.pow, math.min, math.max
local rshift, band, lshift, bor = bit.rshift, bit.band, bit.lshift, bit.bor
local nvim_buf_clear_namespace, nvim_buf_set_extmark, nvim_set_hl =
  vim.api.nvim_buf_clear_namespace, vim.api.nvim_buf_set_extmark, vim.api.nvim_set_hl

---@class oklch.highlight
local M = {}

--- Default parser for highlighting
---@type fun(color: string, format: string|nil): number|nil
M.parse = nil

---@type oklch.FinalPatternList[]
local patterns = nil

---@type oklch.highlight.Opts
local opts = nil

---@type number
local ns
---@type number
local gr

--- @param opts_ oklch.highlight.Opts
--- @param patterns_ oklch.FinalPatternList[]
--- @param auto_download boolean
function M.setup(opts_, patterns_, auto_download)
  opts = opts_
  patterns = patterns_

  if M.make_set_extmark() then
    utils.log("Invalid config.highlight.style, highlighting disabled", vim.log.levels.ERROR)
    opts.enabled = false
    return
  end

  M.update_emphasis_values()

  local on_downloaded = function(err)
    if err then
      utils.log(err, vim.log.levels.ERROR)
      return
    end
    local parser = require("oklch-color-picker.parser").get_parser()
    if parser == nil then
      utils.log("Couldn't load parser library", vim.log.levels.ERROR)
      return
    end
    M.parse = parser.parse

    ns = vim.api.nvim_create_namespace("OklchColorPickerNamespace")
    gr = vim.api.nvim_create_augroup("OklchColorPicker", {})

    if not opts.enabled then
      return
    end

    -- set to false for enable to work
    opts.enabled = false
    M.enable()
  end

  if auto_download then
    downloader.ensure_parser_downloaded(vim.schedule_wrap(on_downloaded))
  else
    on_downloaded(nil)
  end
end

function M.disable()
  if not opts or not opts.enabled then
    return
  end
  opts.enabled = false

  M.bufs = {}
  vim.api.nvim_clear_autocmds({ group = gr })
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)
    end
  end
end

function M.enable()
  if not M.parse or not opts or opts.enabled then
    return
  end
  opts.enabled = true

  vim.api.nvim_create_autocmd("BufEnter", {
    group = gr,
    callback = function(data)
      M.on_buf_enter(data.buf)
    end,
  })

  local init = vim.schedule_wrap(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        M.on_buf_enter(bufnr)
      end
    end
  end)

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = gr,
    callback = function()
      M.clear_hl_cache()
      M.update_emphasis_values()
      init()
    end,
  })

  init()
end

---@return boolean -- true if enabled, false if disabled
function M.toggle()
  if opts.enabled then
    M.disable()
  else
    M.enable()
  end

  return opts.enabled
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
function M.on_buf_enter(bufnr)
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
  if buftype ~= "" then
    return
  end

  if M.bufs[bufnr] then
    M.update_view(bufnr)
    return
  end

  M.bufs[bufnr] = {
    prev_view = { top = 0, bottom = 0 },
  }

  M.update_view(bufnr)

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
        M.update_view(bufnr)
      end,
      on_detach = function()
        M.bufs[bufnr] = nil
        M.buf_attached[bufnr] = nil
        vim.api.nvim_clear_autocmds({ buffer = bufnr, group = gr })
      end,
    })
    M.buf_attached[bufnr] = true
  end

  vim.api.nvim_create_autocmd("WinScrolled", {
    group = gr,
    buffer = bufnr,
    callback = function()
      M.update_view(bufnr)
    end,
  })
end

--- @param bufnr integer
function M.update_view(bufnr)
  local buf_data = M.bufs[bufnr]
  if buf_data == nil then
    return
  end

  local top, bottom = M.get_view(bufnr)
  if top < buf_data.prev_view.top and bottom <= buf_data.prev_view.bottom then
    -- scrolled up
    M.update_lines(bufnr, 0, buf_data.prev_view.top + 1, true)
  elseif bottom > buf_data.prev_view.bottom and top >= buf_data.prev_view.top then
    -- scrolled down
    M.update_lines(bufnr, buf_data.prev_view.bottom, 1e9, true)
  else
    -- large jump
    M.update_lines(bufnr, 0, 1e9, true)
  end
  buf_data.prev_view.top = top
  buf_data.prev_view.bottom = bottom
end

local function get_view()
  return {
    vim.fn.line("w0") - 1,
    -- return one extra line because it doesn't count it if it's wrapped
    vim.fn.line("w$") + 1,
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

---@param enabled? boolean
function M.set_perf_logging(enabled)
  if enabled == nil then
    enabled = true
  end
  M.perf_logging = enabled
end

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

  local delay = assert(scroll and opts.scroll_delay or opts.edit_delay)
  M.pending_timer:stop()

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

  local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

  -- ignore very long lines
  for i, line in ipairs(lines) do
    if string.len(line) > 4000 then
      lines[i] = ""
    end
  end

  M.highlight_lines(bufnr, lines, from_line, ft)

  if M.perf_logging then
    local ms = (vim.uv.hrtime() - t) / 1000000
    print(format("color highlighting took: %.3f ms, lines %d to %d", ms, from_line, to_line))
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

local function rgb_unpack(rgb)
  local r = rshift(rgb, 16)
  local g = band(rshift(rgb, 8), 0xff)
  local b = band(rgb, 0xff)
  return { r, g, b }
end

--- Combines r, g, b (0-255) integer values to a combined color 0xRRGGBB.
--- Passing floats or numbers outside of 0-255 can result in weird outputs.
---@param r integer
---@param g integer
---@param b integer
---@return integer
function M.rgb_pack(r, g, b)
  return bor(lshift(r, 16), lshift(g, 8), b)
end

--- Based on  W3C guidelines
--- https://stackoverflow.com/questions/3942878/how-to-decide-font-color-in-white-or-black-depending-on-background-color
--- @param color [number, number, number]
local function lightness(color)
  return 0.2126 * linear_lookup[color[1]] + 0.7152 * linear_lookup[color[2]] + 0.0722 * linear_lookup[color[3]]
end

--- @param color [number, number, number]
--- @return boolean
local function is_light(color)
  return lightness(color) > 0.179
end

local function square(a)
  return a * a
end

local function color_distance(a, b)
  local r_ = 0.5 * (a[1] + b[1])
  return math.sqrt(
    (2 + r_ / 256) * square(b[1] - a[1]) + 4 * square(b[2] - a[2]) + (2 + (255 - r_) / 256) * square(b[3] - a[3])
  )
end

local function get_hl(hl_name)
  local hl = vim.api.nvim_get_hl(0, { name = hl_name, create = false })
  local i = 0
  while hl and hl.link and i < 50 do
    hl = vim.api.nvim_get_hl(0, { name = hl.link, create = false })
    i = i + 1
  end
  return hl
end

---@type [number, number, number]
local bg_color = { 0, 0, 0 }
local bg_color_is_light = false
local emphasis_threshold = 1.
local light_emphasis = 0
local dark_emphasis = 0

function M.update_emphasis_values()
  local hl = get_hl("Normal")
  if hl.bg then
    bg_color = rgb_unpack(hl.bg)
  else
    bg_color = vim.api.nvim_get_option_value("background", {}) == "light" and { 255, 255, 255 } or { 0, 0, 0 }
  end
  bg_color_is_light = is_light(bg_color)
  emphasis_threshold = opts.emphasis and opts.emphasis.threshold[bg_color_is_light and 2 or 1] or 1
  dark_emphasis = opts.emphasis and opts.emphasis.amount[1] or 0
  light_emphasis = opts.emphasis and opts.emphasis.amount[2] or 0
end

local hex_color_groups = {}

function M.clear_hl_cache()
  hex_color_groups = {}
end

--- @param rgb number
--- @return string
local function compute_color_group(rgb)
  local cached_group_name = hex_color_groups[rgb]
  if cached_group_name ~= nil then
    return cached_group_name
  end

  local hex = format("#%06x", rgb)
  local group_name = format("OCP_%s", sub(hex, 2))

  if opts.style == "background" then
    local opposite = is_light(rgb_unpack(rgb)) and "Black" or "White"
    nvim_set_hl(0, group_name, { fg = opposite, bg = hex })
  else
    local color = rgb_unpack(rgb)
    local bg = "NONE"

    if emphasis_threshold < 1. and color_distance(bg_color, color) < emphasis_threshold * 765 then
      local emphasis = is_light(color) and light_emphasis or dark_emphasis
      for i in ipairs(color) do
        color[i] = min(max(color[i] + emphasis, 0), 255)
      end
      bg = format("#%02x%02x%02x", color[1], color[2], color[3])
    end

    nvim_set_hl(0, group_name, { fg = hex, bg = bg })
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
    priority = opts.priority,
  }
  if opts.style == "background" or opts.style == "foreground" then
    set_extmark = function(bufnr, line_n, start_col, end_col, group)
      reuse_mark.hl_group = group
      reuse_mark.end_col = end_col
      nvim_buf_set_extmark(bufnr, ns, line_n, start_col, reuse_mark)
    end
  elseif opts.style:find("^virtual") then
    reuse_mark.virt_text = { { opts.virtual_text, "" } }
    local virt_arr = reuse_mark.virt_text[1]

    if opts.style == "virtual_left" then
      reuse_mark.virt_text_pos = "inline"
      reuse_mark.right_gravity = false
      reuse_mark.end_right_gravity = false
      set_extmark = function(bufnr, line_n, start_col, end_col, group)
        virt_arr[2] = group
        reuse_mark.end_col = end_col
        nvim_buf_set_extmark(bufnr, ns, line_n, start_col, reuse_mark)
      end
    elseif opts.style == "virtual_right" then
      reuse_mark.virt_text_pos = "inline"
      set_extmark = function(bufnr, line_n, _, end_col, group)
        virt_arr[2] = group
        nvim_buf_set_extmark(bufnr, ns, line_n, end_col, reuse_mark)
      end
    elseif opts.style == "virtual_eol" then
      set_extmark = function(bufnr, line_n, start_col, end_col, group)
        virt_arr[2] = group
        reuse_mark.end_col = end_col
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
            local rgb = pattern_list.custom_parse and pattern_list.custom_parse(color)
              or parse(color, pattern_list.format)

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
