local utils = require("oklch-color-picker.utils")
local highlight = require("oklch-color-picker.highlight")

---@class oklch.picker
local M = {}

---@type oklch.FinalPatternList[]
local final_patterns

---@param final_patterns_ oklch.FinalPatternList
function M.setup(final_patterns_)
  final_patterns = final_patterns_
end

--- @class oklch.picker.PendingEdit
--- @field bufnr number
--- @field changedtick number
--- @field line_number number
--- @field start number
--- @field finish number
--- @field color? string
--- @field color_format? string

--- @type oklch.picker.PendingEdit|nil
local pending_edit = nil

---@param color string
local function apply_new_color(color)
  if not pending_edit then
    utils.log("Don't call apply_new_color if there is no pending edit!!!", vim.log.levels.DEBUG)
    return
  end

  vim.schedule(function()
    if pending_edit.changedtick ~= vim.api.nvim_buf_get_changedtick(pending_edit.bufnr) then
      utils.log(function()
        return string.format("Not applying new color '%s' because the buffer has changed", color)
      end, vim.log.levels.WARN)
      return
    end

    vim.api.nvim_buf_set_text(
      pending_edit.bufnr,
      pending_edit.line_number - 1,
      pending_edit.start - 1,
      pending_edit.line_number - 1,
      pending_edit.finish - 1,
      { color }
    )
    pending_edit = nil

    utils.log(function()
      return "Applied '" .. color .. "'"
    end, vim.log.levels.INFO)
  end)
end

local function start_app()
  if not pending_edit then
    utils.log("Can't start app, no pending edit", vim.log.levels.WARN)
    return false
  end

  local stdout = function(err, data)
    if data then
      utils.log(function()
        return "Stdout: " .. data
      end, vim.log.levels.DEBUG)
      if data == "" then
        utils.log("Picker returned an empty string", vim.log.levels.WARN)
        return
      end
      local color = data:match("^[^\r\n]*")
      apply_new_color(color)
    elseif err then
      utils.log(function()
        return "Stdout error: " .. err
      end, vim.log.levels.DEBUG)
    else
      utils.log("Stdout closed", vim.log.levels.DEBUG)
    end
  end

  local stderr = function(err, data)
    if data then
      utils.log(data, vim.log.levels.WARN)
    elseif err then
      utils.log(function()
        return "Stderr error: " .. err
      end, vim.log.levels.DEBUG)
    else
      utils.log("Stderr closed", vim.log.levels.DEBUG)
    end
  end

  local exec = utils.executable_full_path()
  if exec == nil then
    utils.log("Picker executable not found", vim.log.levels.ERROR)
    return false
  end

  local cmd = { exec }
  if pending_edit.color then
    table.insert(cmd, pending_edit.color)
  end
  if pending_edit.color_format then
    table.insert(cmd, "--format")
    table.insert(cmd, pending_edit.color_format)
  end

  vim.system(cmd, { stdout = stdout, stderr = stderr }, function(res)
    if res.code ~= 0 then
      utils.log(function()
        return "App failed and exited with code " .. res.code
      end, vim.log.levels.DEBUG)
    end
    utils.log(function()
      return "App exited successfully " .. vim.inspect(res)
    end, vim.log.levels.DEBUG)
  end)

  return true
end

--- @param bufnr number
--- @param line string
--- @param line_n number
--- @param cursor_col number
--- @param ft string
--- @return { pos: [number, number], color: string, color_format: string|nil }| nil
local function find_color(bufnr, line, line_n, cursor_col, ft)
  for _, pattern_list in ipairs(final_patterns) do
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
              color = rgb and string.format("#%06x", rgb) or nil
              format = nil
            else
              color = replace
            end

            if color then
              return {
                pos = { replace_start, replace_end },
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

  -- As a last resort, check if we are over a lsp color (change to zero-indexing)
  local buf_data = highlight.bufs[bufnr]
  if not buf_data then
    return nil
  end
  cursor_col = cursor_col - 1
  line_n = line_n - 1
  for _, lsp_colors in pairs(buf_data.lsp_colors) do
    for _, lsp_color in ipairs(lsp_colors) do
      if
        lsp_color.range.start.line == line_n
        and cursor_col >= lsp_color.range.start.character
        and cursor_col < lsp_color.range["end"].character
      then
        local start = lsp_color.range.start.character + 1
        local finish = lsp_color.range["end"].character
        local color = string.format("#%06x", lsp_color.packed_color)
        return {
          pos = { start, finish },
          color = color,
        }
      end
    end
  end

  return nil
end

local function cursor_info()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2] + 1

  local bufnr = vim.api.nvim_get_current_buf()

  return row, col, bufnr
end

---@class picker.PickUnderCursorOpts
---@field force_format? string auto detect by default
---@field fallback_open? picker.OpenPickerOpts open the picker anyway if no color under the cursor is found

--- @param opts? picker.PickUnderCursorOpts|string opts (or `force_color_format` for backwards compatibility)
--- @return boolean success true if a color was found and picker opened
function M.pick_under_cursor(opts)
  local row, col, bufnr = cursor_info()

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })

  local res = find_color(bufnr, line, row, col, ft)

  if not res then
    if type(opts) == "table" and opts.fallback_open then
      return M.open_picker(opts.fallback_open)
    end
    utils.log("No color under cursor", vim.log.levels.INFO)
    return false
  end

  utils.log(function()
    return string.format("Found color '%s' at position %s", res.color, vim.inspect(res.pos))
  end, vim.log.levels.DEBUG)

  local color_format = nil
  if type(opts) == "string" then
    color_format = opts
  elseif type(opts) == "table" then
    color_format = opts.force_format
  end
  color_format = color_format or res.color_format

  pending_edit = {
    bufnr = bufnr,
    changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
    line_number = row,
    start = res.pos[1],
    finish = res.pos[2],
    color = res.color,
    color_format = color_format,
  }

  return start_app()
end

---@class picker.OpenPickerOpts
---@field initial_color? string any color that the picker can parse, e.g. "#fff" (uses a random hex color by default)
---@field force_format? string auto detect by default

--- Open the picker and insert the new color at the cursor position. Ignores whatever is happening under the cursor.
---
--- @param opts? picker.OpenPickerOpts
--- @return boolean success true if the picker was able to open
function M.open_picker(opts)
  local row, col, bufnr = cursor_info()

  pending_edit = {
    bufnr = bufnr,
    changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
    line_number = row,
    start = col,
    finish = col,
    color = opts and opts.initial_color,
    color_format = opts and opts.force_format,
  }

  return start_app()
end

return M
