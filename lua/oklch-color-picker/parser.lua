local utils = require 'oklch-color-picker.utils'

package.cpath = package.cpath .. ';' .. utils.get_path() .. '/?' .. utils.get_lib_extension()

return {
  get_parser = function()
    local success, parser = pcall(require, 'parser_lua_module')
    if success then
      return parser
    end
    return nil
  end,
}