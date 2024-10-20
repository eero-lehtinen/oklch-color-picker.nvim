local utils = require 'oklch-color-picker.utils'
local highlight = require 'oklch-color-picker.highlight'

---@class oklch
local M = {}

---@alias oklch.PatternList { priority: number|nil, format: string|nil, ft: string[]|nil, [number]: string,  }

---@class oklch.Config
local default_config = {
  ---@type { [string]: oklch.PatternList}
  patterns = {
    hex = {
      priority = -1,
      '()#%x%x%x+()%f[%W]',
    },
    css = {
      priority = -1,
      '()rgb%(.+%)()',
      '()oklch%(.+%)()',
      '()hsl%(.+%)()',
    },
    numbers_in_brackets = {
      priority = -10,
      '%(()[%d.,%s]+()%)',
    },
  },
  highlight = {
    ---@type boolean
    enabled = true,
    ---@type number async delay in ms
    delay = 60,
  },
  ---@type integer
  log_level = vim.log.levels.INFO,
}

---@type oklch.Config
M.config = {}

---@alias oklch.FinalPatternList { priority: number, name: string, format: string|nil, ft: string[]|nil, [number]: string,  }

--- @type oklch.FinalPatternList[]
M.final_patterns = {}

---@param config oklch.Config
function M.setup(config)
  M.config = vim.tbl_deep_extend('force', default_config, config or {})
  utils.setup(M.config)

  vim.api.nvim_create_user_command('ColorPickOklch', function()
    M.pick_under_cursor()
  end, {})

  for key, pattern_list in pairs(M.config.patterns) do
    table.insert(M.final_patterns, {
      name = key,
      priority = pattern_list.priority or 0,
      format = pattern_list.format,
      ft = pattern_list.ft,
    })
    for i, pattern in ipairs(pattern_list) do
      M.final_patterns[#M.final_patterns][i] = '()' .. pattern .. '()'
    end
  end

  table.sort(M.final_patterns, function(a, b)
    return a.priority > b.priority
  end)

  highlight.setup(M.config.highlight, M.final_patterns)
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

  local path = utils.get_path()
  local cmd = { utils.executable(), pending_edit.color }
  if pending_edit.color_format then
    table.insert(cmd, '--format')
    table.insert(cmd, pending_edit.color_format)
  end

  vim.system(cmd, { env = { PATH = path }, stdout = stdout, stderr = stderr }, function(res)
    if res.code ~= 0 then
      utils.log('App failed and exited with code ' .. res.code, vim.log.levels.DEBUG)
    end
    utils.log('App exited successfully ' .. vim.inspect(res), vim.log.levels.DEBUG)
  end)
end

--- @param line string
--- @param cursor_col number
--- @param ft string|nil
--- @return { pos: [number, number], color: string, color_format: string|nil }| nil
local function find_color(line, cursor_col, ft)
  for _, pattern_list in ipairs(M.final_patterns) do
    if pattern_list and (not pattern_list.ft or (ft and vim.tbl_contains(pattern_list.ft, ft))) then
      for i, pattern in ipairs(pattern_list) do
        for match_start, replace_start, replace_end, match_end in line:gmatch(pattern) do
          if type(match_start) ~= 'number' or type(replace_start) ~= 'number' or type(replace_end) ~= 'number' or type(match_end) ~= 'number' then
            utils.report_invalid_pattern(pattern_list.name, i, pattern)
            return nil
          else
            if cursor_col >= match_start and cursor_col <= match_end - 1 then
              return {
                pos = { replace_start, replace_end - 1 },
                color = line:sub(replace_start --[[@as number]], replace_end - 1),
                color_format = pattern_list.format,
              }
            end
          end
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

return M
