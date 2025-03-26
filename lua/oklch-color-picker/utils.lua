local M = {}

---@type oklch.Opts
local opts

---@param opts_ oklch.Opts
function M.setup(opts_)
  opts = opts_
end

---@param fn_or_msg (fun(): string)|string
---@param level integer
function M.log(fn_or_msg, level)
  if level >= opts.log_level then
    vim.schedule(function()
      local msg = "oklch-color-picker: " .. (type(fn_or_msg) == "string" and fn_or_msg or fn_or_msg())

      if level == vim.log.levels.INFO then
        -- trim beginning until echospace
        local max_len = vim.v.echospace
        local len = msg:len()
        if len > max_len then
          msg = "<" .. msg:sub(len - max_len + 2)
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
  M.log(function()
    return string.format(
      [[
Pattern %s[%d] = '%s' is invalid: %s

The pattern should contain exactly two empty groups '()' to designate the replacement range and no other groups. Remember to escape literal parentheses: '%%(' and '%%)'
]],
      pattern_list_name,
      i,
      pattern,
      details
    )
  end, vim.log.levels.ERROR)
end

---@return boolean
function M.is_windows()
  return jit.os == "Windows"
end

---@return boolean
function M.is_macos()
  return jit.os == "OSX"
end

function M.is_wsl()
  return opts.wsl_use_windows_app and vim.env.WSL_INTEROP ~= nil
end

---@return string
function M.executable()
  local executable_ext = (M.is_windows() or M.is_wsl()) and ".exe" or ""
  return "oklch-color-picker" .. executable_ext
end

M.exec = nil

---@return string|nil
function M.executable_full_path()
  if M.exec then
    return M.exec
  end
  local exec = M.get_path() .. "/" .. M.executable()
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
  path = vim.fn.stdpath("data") .. "/oklch-color-picker"
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
  return path
end

--- @return string
function M.get_lib_extension()
  if M.is_macos() then
    return ".dylib"
  end
  if M.is_windows() then
    return ".dll"
  end
  return ".so"
end

return M
