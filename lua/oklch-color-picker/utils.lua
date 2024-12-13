local M = {}

local log_level = vim.log.levels.INFO

---@param log_level_ integer
function M.setup(log_level_)
  log_level = log_level_
end

---@param msg string
---@param level integer
function M.log(msg, level)
  if level >= log_level then
    vim.schedule(function()
      msg = 'oklch-color-picker: ' .. msg

      if level == vim.log.levels.INFO then
        -- trim beginning until echospace
        local max_len = vim.v.echospace
        local len = msg:len()
        if len > max_len then
          msg = '<' .. msg:sub(len - max_len + 2)
        end
      end

      vim.notify(msg, level)
    end)
  end
end

--- @param pattern_list_name string
--- @param i integer
--- @param pattern string
--- @param details string
function M.report_invalid_pattern(pattern_list_name, i, pattern, details)
  M.log(
    string.format(
      [[
Pattern %s[%d] = '%s' is invalid: %s

The pattern should contain exactly two empty groups '()' to designate the replacement range and no other groups. Remember to escape literal parentheses: '%%(' and '%%)'
]],
      pattern_list_name,
      i,
      pattern,
      details
    ),
    vim.log.levels.ERROR
  )
end

---@return boolean
function M.is_windows()
  return vim.loop.os_uname().sysname:find 'Windows' ~= nil
end

---@return boolean
function M.is_macos()
  return vim.loop.os_uname().sysname:find 'Darwin' ~= nil
end

---@return string
function M.executable()
  local executable_ext = M.is_windows() and '.exe' or ''
  return 'oklch-color-picker' .. executable_ext
end

M.exec = nil

---@return string|nil
function M.executable_full_path()
  if M.exec then
    return M.exec
  end
  local exec = M.get_path() .. '/' .. M.executable()
  if vim.fn.executable(exec) == 1 then
    M.exec = exec
    return M.exec
  end
  return nil
end

--- @type string|nil
local path

---@return string
function M.get_path()
  if path ~= nil then
    return path
  end
  path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
  return path
end

--- @return string
function M.get_lib_extension()
  if M.is_macos() then
    return '.dylib'
  end
  if M.is_windows() then
    return '.dll'
  end
  return '.so'
end

return M
