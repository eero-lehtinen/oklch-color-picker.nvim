local utils = require("oklch-color-picker.utils")

---@class oklch.picker
local M = {}

---@type oklch.FinalPatternList[]
local final_patterns

---@param final_patterns_ oklch.FinalPatternList
function M.setup(final_patterns_)
  final_patterns = final_patterns_
end

--- @alias oklch.picker.PendingEdit { bufnr: number, changedtick: number, line_number: number, start: number, finish: number, color: string, color_format: string|nil }|nil

--- @type oklch.picker.PendingEdit
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
      utils.log("Stdout: " .. data, vim.log.levels.DEBUG)
      if data == "" then
        utils.log("Picker returned an empty string", vim.log.levels.WARN)
        return
      end
      local color = data:match("^[^\r\n]*")
      apply_new_color(color)
    elseif err then
      utils.log("Stdout error: " .. err, vim.log.levels.DEBUG)
    else
      utils.log("Stdout closed", vim.log.levels.DEBUG)
    end
  end

  local stderr = function(err, data)
    if data then
      utils.log(data, vim.log.levels.WARN)
    elseif err then
      utils.log("Stderr error: " .. err, vim.log.levels.DEBUG)
    else
      utils.log("Stderr closed", vim.log.levels.DEBUG)
    end
  end

  local exec = utils.executable_full_path()
  if exec == nil then
    utils.log("Picker executable not found", vim.log.levels.ERROR)
    return
  end

  local cmd = { exec, pending_edit.color }
  if pending_edit.color_format then
    table.insert(cmd, "--format")
    table.insert(cmd, pending_edit.color_format)
  end

  vim.system(cmd, { stdout = stdout, stderr = stderr }, function(res)
    if res.code ~= 0 then
      utils.log("App failed and exited with code " .. res.code, vim.log.levels.DEBUG)
    end
    utils.log("App exited successfully " .. vim.inspect(res), vim.log.levels.DEBUG)
  end)
end

--- @param line string
--- @param cursor_col number
--- @param ft string
--- @return { pos: [number, number], color: string, color_format: string|nil }| nil
local function find_color(line, cursor_col, ft)
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
  local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })

  local res = find_color(line, col, ft)

  if not res then
    utils.log("No color under cursor", vim.log.levels.INFO)
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

return M
