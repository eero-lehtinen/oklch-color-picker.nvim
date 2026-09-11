local highlight = require("oklch-color-picker.highlight")

local M = {}

M.ns = nil

--- BufData tables for buffers driven by direct `highlight_lines` calls, which
--- deliberately bypass `highlight.bufs` and its timers.
---@type table<integer, table>
M.data = {}

M.notifications = {}

---@param opts table|string|nil a Lua expression when msgpack cannot carry it
---@param expect_disabled boolean|nil highlighting is expected to fail to start
function M.setup(opts, expect_disabled)
  vim.notify = function(msg, level)
    table.insert(M.notifications, { msg = msg, level = level })
  end

  if type(opts) == "string" then
    opts = assert(loadstring("return " .. opts))()
  end

  require("oklch-color-picker").setup(vim.tbl_deep_extend("force", {
    auto_download = false,
    register_cmds = false,
    highlight = { enabled = false, edit_delay = 0, scroll_delay = 0, lsp_delay = 0 },
  }, opts or {}))

  M.ns = vim.api.nvim_create_namespace("OklchColorPickerNamespace")

  if expect_disabled then
    return
  end
  assert(highlight.parse ~= nil, "parser not loaded, run tests/bootstrap.lua")
  -- Groups are cached by color for the lifetime of the process, so a case that
  -- changes the style would otherwise inspect the previous case's definitions.
  highlight.clear_hl_cache()
  highlight.update_emphasis_values()
end

--- Shape of the single extmark in `buf`, with absent fields as `false` so the
--- comparison survives the round trip.
---@param buf integer
---@return table
function M.mark_detail(buf)
  local m = vim.api.nvim_buf_get_extmarks(buf, M.ns, 0, -1, { details = true })[1]
  local d = m[4]
  return {
    start_col = m[3],
    end_col = d.end_col,
    hl_group = d.hl_group or false,
    virt_text = d.virt_text and d.virt_text[1][1] or false,
    virt_text_group = d.virt_text and d.virt_text[1][2] or false,
    virt_text_pos = d.virt_text_pos or false,
    right_gravity = d.right_gravity == true,
    end_right_gravity = d.end_right_gravity == true,
  }
end

---@param name string
---@return table
function M.hl_def(name)
  local hl = vim.api.nvim_get_hl(0, { name = name })
  return {
    fg = hl.fg or false,
    bg = hl.bg or false,
    bold = hl.bold == true,
    italic = hl.italic == true,
  }
end

---@param pattern string
---@return string|nil
function M.wait_notification(pattern)
  local found
  vim.wait(1000, function()
    for _, n in ipairs(M.notifications) do
      if n.msg:find(pattern, 1, true) then
        found = n.msg
        return true
      end
    end
    return false
  end, 5)
  return found
end

---@param lines string[]
---@param ft string|nil
---@return integer
local function new_buf(lines, ft)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if ft then
    vim.api.nvim_set_option_value("filetype", ft, { buf = buf })
  end
  return buf
end

---@param lines string[]
---@param ft string|nil
---@return integer
function M.detached_buf(lines, ft)
  local buf = new_buf(lines, ft)
  M.data[buf] = { lsp_namespaces = {}, lsp_namespaces_list = {}, mark_caches = {} }
  return buf
end

--- Hands a detached buffer's data to the plugin, for the functions that look it
--- up in `highlight.bufs` instead of taking it as an argument.
---@param buf integer
function M.register(buf)
  highlight.bufs[buf] = M.data[buf]
end

---@param lines string[]
---@param ft string|nil
---@return integer
function M.live_buf(lines, ft)
  local buf = new_buf(lines, ft)
  vim.api.nvim_win_set_buf(0, buf)
  highlight.init_buf(buf)
  return buf
end

---@param text string
---@return integer
function M.term_buf(text)
  local buf = vim.api.nvim_create_buf(true, false)
  local chan = vim.api.nvim_open_term(buf, {})
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_chan_send(chan, text .. "\r\n")
  vim.wait(1000, function()
    return (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""):find(text, 1, true) ~= nil
  end, 5)
  highlight.init_buf(buf)
  return buf
end

---@param buf integer
function M.rehl(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
  highlight.highlight_lines(buf, lines, 0, ft, M.data[buf])
end

--- Places an extmark and cache entry in an LSP namespace exactly as the
--- documentColor handler would, without running a server.
---@param buf integer
---@param row integer
---@param start_col integer
---@param end_col integer
---@param client string|nil
---@return integer mark_id
function M.add_lsp_mark(buf, row, start_col, end_col, client)
  client = client or "fake"
  local data = M.data[buf]
  local lsp_ns = vim.api.nvim_create_namespace("OklchColorPickerLsp_" .. client)
  if data.lsp_namespaces[client] == nil then
    data.lsp_namespaces[client] = lsp_ns
    table.insert(data.lsp_namespaces_list, lsp_ns)
  end
  if data.mark_caches[lsp_ns] == nil then
    data.mark_caches[lsp_ns] = { texts = {}, priorities = {} }
  end
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local id = vim.api.nvim_buf_set_extmark(buf, lsp_ns, row, start_col, { end_col = end_col })
  data.mark_caches[lsp_ns].texts[id] = line:sub(start_col + 1, end_col)
  return id
end

---@param client string|nil
---@return integer
local function namespace(client)
  return client and vim.api.nvim_create_namespace("OklchColorPickerLsp_" .. client) or M.ns
end

--- Marks as `"row:start-end:group"`, or `"row:start-row:end:group"` when a mark
--- spans lines. Already ordered by position by the API.
---@param buf integer
---@param client string|nil
---@return string[]
function M.marks(buf, client)
  local out = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace(client), 0, -1, { details = true })) do
    local d = m[4]
    local group = d.hl_group or (d.virt_text and d.virt_text[1][2]) or "none"
    local pos = m[2] == d.end_row and string.format("%d:%d-%d", m[2], m[3], d.end_col)
      or string.format("%d:%d-%d:%d", m[2], m[3], d.end_row, d.end_col)
    out[#out + 1] = pos .. ":" .. group
  end
  return out
end

---@param buf integer
---@param client string|nil
---@return integer[]
function M.mark_ids(buf, client)
  local out = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace(client), 0, -1, {})) do
    out[#out + 1] = m[1]
  end
  return out
end

---@param buf integer
---@param client string|nil
---@return integer
function M.mark_count(buf, client)
  return #vim.api.nvim_buf_get_extmarks(buf, namespace(client), 0, -1, {})
end

---@param buf integer
---@param expected string[]
---@param client string|nil
---@return string[]
function M.wait_marks(buf, expected, client)
  local got
  vim.wait(1000, function()
    got = M.marks(buf, client)
    return vim.deep_equal(got, expected)
  end, 5)
  return got
end

---@param buf integer
---@param expected integer
---@return integer
function M.wait_marks_count(buf, expected)
  vim.wait(1000, function()
    return M.mark_count(buf) == expected
  end, 5)
  return M.mark_count(buf)
end

---@param buf integer
---@param expected string
---@return string|nil
function M.wait_last_mark(buf, expected)
  local last
  vim.wait(1000, function()
    local all = M.marks(buf)
    last = all[#all]
    return last == expected
  end, 5)
  return last
end

--- Checks the cache invariant: every live mark has an entry, and LSP entries
--- have the mark's exact length because the overlap check derives the mark
--- end from it. Main namespace entries hold the pattern's replacement range,
--- which can be shorter than the mark, so only their presence is checked.
--- Stale entries are allowed: Nvim deletes a mark whose whole text is removed
--- without telling the plugin, and the plugin accepts that.
---@param buf integer
---@return string[]
function M.cache_problems(buf)
  local data = highlight.bufs[buf] or M.data[buf]
  if data == nil then
    return { "no buf data" }
  end

  local problems = {}
  for ns_id, cache in pairs(data.mark_caches) do
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns_id, 0, -1, { details = true })) do
      local id, text = m[1], cache.texts[m[1]]
      local span = m[4].end_row == m[2] and m[4].end_col - m[3] or -1
      if text == nil then
        problems[#problems + 1] = string.format("ns %d: live mark %d is not cached", ns_id, id)
      elseif ns_id ~= M.ns and span ~= #text then
        problems[#problems + 1] =
          string.format("ns %d: id %d caches %q (%d bytes) but its mark spans %d", ns_id, id, text, #text, span)
      end
    end
  end
  table.sort(problems)
  return problems
end

---@type { cmd: string[], stdout: fun(err: string|nil, data: string|nil), on_exit: fun(res: table) }[]
M.system_calls = {}

--- Replaces `vim.system` so the picker app is never launched. Each call is
--- recorded; `picker_reply` feeds its output back.
function M.stub_system()
  M.system_calls = {}
  require("oklch-color-picker.utils").exec = "fake-picker"
  vim.system = function(cmd, opts, on_exit)
    table.insert(M.system_calls, { cmd = cmd, stdout = opts.stdout, on_exit = on_exit })
    return {}
  end
end

---@param data string
function M.picker_reply(data)
  local call = M.system_calls[#M.system_calls]
  call.stdout(nil, data)
  call.stdout(nil, nil)
  call.on_exit({ code = 0 })
end

---@param buf integer
---@param row integer
---@param expected string
---@return string
function M.wait_line(buf, row, expected)
  local got
  vim.wait(1000, function()
    got = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    return got == expected
  end, 5)
  return got
end

---@type table<string, table>
M.lsp = {}

--- In-process LSP server answering `textDocument/documentColor`.
---@param buf integer
---@param client string
---@param colors table[]
---@return integer client_id
function M.start_lsp(buf, client, colors)
  local state = { colors = colors or {}, requests = 0, err = nil }
  M.lsp[client] = state

  local id = vim.lsp.start({
    name = client,
    cmd = function(dispatchers)
      local closing = false
      local request_id = 0
      return {
        request = function(method, _, callback)
          request_id = request_id + 1
          if method == "initialize" then
            callback(nil, { capabilities = { colorProvider = true } })
          elseif method == "textDocument/documentColor" then
            state.requests = state.requests + 1
            -- The plugin rewrites ranges in place, which is fine for a real
            -- server's freshly decoded response but would corrupt our fixture.
            local reply = vim.deepcopy(state.colors)
            vim.schedule(function()
              callback(state.err, state.err == nil and reply or nil)
            end)
          else
            callback(nil, nil)
          end
          return true, request_id
        end,
        notify = function(method)
          if method == "exit" then
            dispatchers.on_exit(0, 15)
          end
          return true
        end,
        is_closing = function()
          return closing
        end,
        terminate = function()
          closing = true
        end,
      }
    end,
    root_dir = vim.uv.cwd(),
  }, { bufnr = buf })

  assert(id, "failed to start fake LSP")
  vim.wait(1000, function()
    return #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentColor" }) > 0
  end, 5)
  return id
end

---@param client string
---@param colors table[]
function M.set_lsp_colors(client, colors)
  M.lsp[client].colors = colors
end

---@param client string
---@param err table|nil
function M.set_lsp_error(client, err)
  M.lsp[client].err = err
end

---@param buf integer
function M.request_lsp(buf)
  highlight.update_lsp(buf, highlight.bufs[buf])
end

--- Skips the debounce timer and waits for the whole round to report back.
---@param buf integer
---@return boolean
function M.request_lsp_sync(buf)
  local done = false
  highlight.process_update_lsp(buf, function()
    done = true
  end)
  return vim.wait(1000, function()
    return done
  end, 5)
end

---@param client string
---@param n integer
---@return integer
function M.wait_lsp_requests(client, n)
  vim.wait(1000, function()
    return M.lsp[client].requests >= n
  end, 5)
  return M.lsp[client].requests
end

---@param buf integer
---@return boolean
function M.wait_lsp_idle(buf)
  return vim.wait(1000, function()
    return highlight.bufs[buf].lsp_in_flight ~= true
  end, 5)
end

---@param red number
---@param green number
---@param blue number
---@param row integer
---@param start_col integer
---@param end_col integer
---@return table
function M.lsp_color(red, green, blue, row, start_col, end_col)
  return {
    range = { start = { line = row, character = start_col }, ["end"] = { line = row, character = end_col } },
    color = { red = red, green = green, blue = blue, alpha = 1 },
  }
end

return M
