local M = {}

---@type oklch.Config
M.config = nil

---@param config oklch.Config
function M.setup(config)
  M.config = config
end

---@param msg string
---@param level integer
function M.log(msg, level)
  if level >= (M.config ~= nil and M.config.log_level or vim.log.levels.INFO) then
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
function M.report_invalid_pattern(pattern_list_name, i, pattern)
  M.log(
    string.format(
      "Pattern %s[%d] = '%s' is invalid. It should contain two empty '()' groups to designate the replacement range and no other groups. Remember to escape literal brackets: '%%(' and '%%)'",
      pattern_list_name,
      i,
      pattern
    ),
    vim.log.levels.ERROR
  )
end

---@return string
function M.root_path()
  local path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
  path = path:gsub('/[^/]-/[^/]-$', '')
  return path
end

---@return boolean
function M.is_windows()
  return vim.loop.os_uname().sysname:find 'Windows' ~= nil
end

---@return string
function M.executable()
  local executable_ext = M.is_windows() and '.exe' or ''
  return 'oklch-color-picker' .. executable_ext
end

M.executable_warned = false

---@return string|nil
function M.executable_full_path(nowarn)
  if vim.fn.executable(M.executable()) == 1 then
    return M.executable()
  else
    local exec = M.get_path() .. M.executable()
    if vim.fn.executable(exec) == 1 then
      return exec
    end
    if not M.executable_warned and not nowarn then
      M.executable_warned = true
      M.log("Executable 'oklch-color-picker' not found. Please download it.", vim.log.levels.ERROR)
    end
    return nil
  end
end

--- @type string|nil
local path

---@return string
function M.get_path()
  if path ~= nil then
    return path
  end
  path = M.root_path() .. '/app/'
  return path
end

return M
