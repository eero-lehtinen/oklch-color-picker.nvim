local utils = require("oklch-color-picker.utils")

local M = {}

--- Packaged installs put the picker in <prefix>/bin and the parser library in
--- <prefix>/lib. Looking there first keeps the parser and picker versions
--- matched when the picker comes from PATH.
---@return table|nil
local function load_next_to_picker()
  local _, exec = utils.executable_full_path()
  if not exec then
    return nil
  end
  exec = vim.uv.fs_realpath(exec) or exec
  local prefix = vim.fs.dirname(vim.fs.dirname(exec))
  local ext = utils.get_lib_extension()
  local candidates = {
    prefix .. "/lib/libparser_lua_module" .. ext,
    prefix .. "/lib/parser_lua_module" .. ext,
    prefix .. "/bin/parser_lua_module" .. ext,
  }
  for _, path in ipairs(candidates) do
    if vim.uv.fs_stat(path) then
      local loader, err = package.loadlib(path, "luaopen_parser_lua_module")
      if loader then
        return loader()
      end
      utils.log(function()
        return "Parser load failed from " .. path .. ":\n" .. tostring(err)
      end, vim.log.levels.DEBUG)
    end
  end
  return nil
end

---@param auto_download boolean
---@return table|nil
function M.get_parser(auto_download)
  if not auto_download then
    local parser = load_next_to_picker()
    if parser then
      return parser
    end
  end
  local original_cpath = package.cpath
  package.cpath = package.cpath .. ";" .. utils.get_path() .. "/?" .. utils.get_lib_extension()
  local success, parser = pcall(require, "parser_lua_module")
  package.cpath = original_cpath
  if success then
    return parser
  end
  utils.log(function()
    return "Parser load failed:\n" .. vim.inspect(parser)
  end, vim.log.levels.DEBUG)
  return nil
end

return M