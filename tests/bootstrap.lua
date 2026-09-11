-- Downloads the parser library into tests/.deps/data through the plugin's own
-- downloader, so the suite uses the pinned parser version and leaves the user's
-- data directory alone.

local tests_dir = vim.fs.dirname(vim.fs.normalize(debug.getinfo(1, "S").source:sub(2)))

dofile(tests_dir .. "/minimal_init.lua")

local utils = require("oklch-color-picker.utils")
utils.setup({ log_level = vim.log.levels.INFO, auto_download = true })

local done, failure = false, nil
require("oklch-color-picker.downloader").ensure_parser_downloaded(function(err)
  failure = err
  done = true
end)

if not vim.wait(120000, function()
  return done
end, 20) then
  io.stderr:write("Parser download timed out\n")
  os.exit(1)
end

if failure then
  io.stderr:write(failure .. "\n")
  os.exit(1)
end

print("Parser ready in " .. utils.get_path())
