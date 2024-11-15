local utils = require 'oklch-color-picker.utils'
local downloader = require 'oklch-color-picker.downloader'
local color_to_hex

local find, sub, format = string.find, string.sub, string.format
local nvim_buf_clear_namespace, nvim_buf_add_highlight, nvim_set_hl = vim.api.nvim_buf_clear_namespace, vim.api.nvim_buf_add_highlight, vim.api.nvim_set_hl
local pow, sqrt, min, max = math.pow, math.sqrt, math.min, math.max
local rshift, band = bit.rshift, bit.band

local M = {}

--- @class oklch.HightlightConfig
--- @field enabled boolean
--- @field edit_delay number async delay in ms
--- @field scroll_delay number async delay in ms

M.patterns = nil

---@type oklch.HightlightConfig
M.config = nil

local ns

--- @param config oklch.HightlightConfig
--- @param patterns oklch.FinalPatternList[]
--- @param auto_download boolean
function M.setup(config, patterns, auto_download)
  M.config = config
  M.patterns = patterns

  if not M.config.enabled then
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
    color_to_hex = parser.color_to_hex

    ns = vim.api.nvim_create_namespace 'OklchColorPickerNamespace'
    M.gr = vim.api.nvim_create_augroup('OklchColorPicker', {})

    -- set to false for enable to work
    M.config.enabled = false
    M.enable()
  end

  if auto_download then
    downloader.ensure_parser_downloaded(vim.schedule_wrap(on_downloaded))
  else
    on_downloaded(nil)
  end
end

function M.disable()
  if not M.config or not M.config.enabled then
    return
  end
  M.config.enabled = false

  M.bufs = {}
  vim.api.nvim_clear_autocmds { group = M.gr }
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)
    end
  end
end

function M.enable()
  if not color_to_hex or not M.config or M.config.enabled then
    return
  end
  M.config.enabled = true

  vim.api.nvim_create_autocmd('BufEnter', {
    group = M.gr,
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
  if M.config.enabled then
    M.disable()
  else
    M.enable()
  end
end

---@class BufData
---@field pending_updates { from_line: integer, to_line: integer }|nil
---@field line_cache table<integer, string|nil>
---@field invalidate { from_line: integer, to_line: integer }|nil

--- @type { [integer]: BufData }
M.bufs = {}
--- @type integer
M.gr = nil

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
    pending_updates = nil,
    line_cache = {},
    invalidate = nil,
  }

  M.update(bufnr)

  if M.buf_attached[bufnr] == nil then
    vim.api.nvim_buf_attach(bufnr, false, {
      on_bytes = function(_, _, _, start_row, _, _, old_end_row, _, _, new_end_row, _, _)
        if new_end_row < old_end_row then
          -- We deleted some lines.
          -- It's possible that we uncovered new unhighlighted colors from the bottom
          -- of the view, so update the rest of the view.
          -- We could move the cache up here, but it could be an expensive operation on massive files.
          M.update_lines(bufnr, start_row, 100000000, false)
        else
          -- Invalidate added lines as it's impossible for them to already have correct highlights.
          -- We could technically move the cache down, but that could be a fairly expensive operation
          -- and can't be done asynchronously.
          local buf_data = M.bufs[bufnr]
          if buf_data then
            local invalidate = {
              from_line = start_row + 1,
              to_line = start_row + new_end_row + 1,
            }
            if buf_data.invalidate == nil then
              buf_data.invalidate = invalidate
            else
              buf_data.invalidate.from_line = min(buf_data.invalidate.from_line, invalidate.from_line)
              buf_data.invalidate.to_line = max(buf_data.invalidate.to_line, invalidate.to_line)
            end
          end
          M.update_lines(bufnr, start_row, start_row + new_end_row + 1, false)
        end
      end,
      on_reload = function()
        M.force_update(bufnr)
      end,
      on_detach = function()
        M.bufs[bufnr] = nil
        M.buf_attached[bufnr] = nil
      end,
    })
    M.buf_attached[bufnr] = true
  end

  vim.api.nvim_create_autocmd('WinScrolled', {
    group = M.gr,
    buffer = bufnr,
    callback = function(data)
      M.update(data.buf)
    end,
  })
end

--- @param bufnr integer
function M.update(bufnr)
  M.update_lines(bufnr, 0, 100000000, true)
end

--- @param bufnr integer
function M.force_update(bufnr)
  local buf_data = M.bufs[bufnr]
  if buf_data then
    buf_data.line_cache = {}
  end
  M.update_lines(bufnr, 0, 100000000, true)
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

  if buf_data.pending_updates == nil then
    buf_data.pending_updates = {
      from_line = max(from_line, vim.fn.line 'w0' - 1),
      to_line = min(to_line, vim.fn.line 'w$'),
    }
  else
    buf_data.pending_updates.from_line = max(min(buf_data.pending_updates.from_line, from_line), vim.fn.line 'w0' - 1)
    buf_data.pending_updates.to_line = min(max(buf_data.pending_updates.to_line, to_line), vim.fn.line 'w$')
  end

  local process_update = function()
    local buf_data = M.bufs[bufnr]
    if buf_data == nil or buf_data.pending_updates == nil then
      return
    end

    local t = vim.uv.hrtime()

    local from_line = buf_data.pending_updates.from_line --[[@as integer]]
    local to_line = buf_data.pending_updates.to_line --[[@as integer]]
    buf_data.pending_updates = nil

    if buf_data.invalidate ~= nil then
      if buf_data.invalidate.to_line - buf_data.invalidate.from_line > 120 then
        buf_data.line_cache = {}
      else
        for i = buf_data.invalidate.from_line, buf_data.invalidate.to_line do
          buf_data.line_cache[i] = nil
        end
      end
      buf_data.invalidate = nil
    end

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

  local delay = scroll and M.config.scroll_delay or M.config.edit_delay
  M.pending_timer:stop()
  if delay > 0 then
    M.pending_timer:start(delay, 0, vim.schedule_wrap(process_update))
  else
    process_update()
  end
end)

local function to_linear(c)
  if c <= 0.03928 then
    return c / 12.92
  else
    return pow((c + 0.055) / 1.055, 2.4)
  end
end

local function cbrt(c)
  return pow(c, 1 / 3)
end

local k_1 = 0.206
local k_2 = 0.03
local k_3 = (1. + k_1) / (1. + k_2)

--- Perceptual lightness estimate
--- https://bottosson.github.io/posts/colorpicker/#intermission---a-new-lightness-estimate-for-oklab
--- @param hex string
--- @return number
local function oklab_lightness(hex)
  local number = tonumber(hex, 16)
  local r = rshift(number, 16) / 255
  local g = band(rshift(number, 8), 0xff) / 255
  local b = band(number, 0xff) / 255
  local lr = to_linear(r)
  local lg = to_linear(g)
  local lb = to_linear(b)
  local l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
  local m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
  local s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb
  local l_ = cbrt(l)
  local m_ = cbrt(m)
  local s_ = cbrt(s)
  local ll = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
  return 0.5 * (k_3 * ll - k_1 + sqrt((k_3 * ll - k_1) * (k_3 * ll - k_1) + 4 * k_2 * k_3 * ll))
end

local hex_color_groups = {}

--- @param hex_color string
--- @return string
local function compute_hex_color_group(hex_color)
  local cached_group_name = hex_color_groups[hex_color]
  if cached_group_name ~= nil then
    return cached_group_name
  end

  local hex = sub(hex_color, 2)
  local group_name = format('OklchColorPickerHexColor_%s', hex)

  local fg = (oklab_lightness(hex) < 0.5) and 'White' or 'Black'
  nvim_set_hl(0, group_name, { fg = fg, bg = hex_color })

  hex_color_groups[hex_color] = group_name

  return group_name
end

local line_matches = {}

---@param bufnr integer
---@param lines string[]
---@param from_line integer
---@param ft string
function M.highlight_lines(bufnr, lines, from_line, ft)
  local patterns = M.patterns
  local line_cache = M.bufs[bufnr].line_cache

  for i, line in ipairs(lines) do
    local line_n = from_line + i - 1 -- zero based index

    if line_cache[line_n + 1] ~= line then
      line_cache[line_n + 1] = line

      nvim_buf_clear_namespace(bufnr, ns, line_n, line_n + 1)

      for j = 1, #line_matches do
        line_matches[j] = nil
      end
      local match_idx = 1

      for _, pattern_list in ipairs(patterns) do
        if pattern_list.ft(ft) then
          for _, pattern in ipairs(pattern_list) do
            local start = 1
            local match_start, match_end = find(line, pattern.cheap, start)

            while match_start ~= nil do
              local replace_start, replace_end
              if pattern.simple_groups then
                replace_start, replace_end = match_start, match_end
              else
                _, _, replace_start, replace_end = find(line, pattern.grouped, match_start)
                replace_end = replace_end - 1
              end

              local has_space = true
              for _, match in ipairs(line_matches) do
                if not (match[1] > match_end or match[2] < match_start) then
                  has_space = false
                  break
                end
              end

              if has_space then
                local color = sub(line, replace_start --[[@as number]], replace_end)
                local hex = color_to_hex(color, pattern_list.format)

                if hex then
                  local group = compute_hex_color_group(hex)
                  nvim_buf_add_highlight(bufnr, ns, group, line_n, match_start - 1, match_end --[[@as number]])
                end
                line_matches[match_idx] = { match_start, match_end }
                match_idx = match_idx + 1
              end

              start = match_end + 1
              match_start, match_end = find(line, pattern.cheap, start)
            end
          end
        end
      end
    end
  end
end

return M
