local tests_dir = vim.fs.dirname(vim.fs.normalize(debug.getinfo(1, "S").source:sub(2)))
local repo = vim.fs.dirname(tests_dir)
local deps = tests_dir .. "/.deps"

-- Set as an environment variable rather than in Lua so the child Neovims
-- inherit it: the plugin resolves the parser through `stdpath("data")`, which
-- must point at the copy bootstrap.lua downloaded.
vim.uv.os_setenv("XDG_DATA_HOME", deps .. "/data")

local mini = deps .. "/mini.nvim"
if vim.fn.isdirectory(mini) == 0 then
  vim.fn.mkdir(deps, "p")
  local out = vim.fn.system({ "git", "clone", "--depth", "1", "https://github.com/echasnovski/mini.nvim", mini })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone mini.nvim:\n" .. out)
  end
end

vim.opt.rtp:prepend(repo)
vim.opt.rtp:prepend(mini)
package.path = tests_dir .. "/?.lua;" .. package.path

vim.o.swapfile = false

require("mini.test").setup()
