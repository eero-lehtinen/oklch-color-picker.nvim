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

---@return string
function M.root_path()
  return vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h') .. '/../..'
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

return M
