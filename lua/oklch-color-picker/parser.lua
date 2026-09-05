local utils = require("oklch-color-picker.utils")

return {
  ---@param auto_download boolean
  get_parser = function(auto_download)
    local original_cpath = package.cpath
    if auto_download then
      package.cpath = package.cpath .. ";" .. utils.get_path() .. "/?" .. utils.get_lib_extension()
    end
    local success, parser = pcall(require, "parser_lua_module")
    package.cpath = original_cpath
    if success then
      return parser
    end
    utils.log(function()
      return "Parser load failed:\n" .. vim.inspect(parser)
    end, vim.log.levels.DEBUG)
    return nil
  end,
}
