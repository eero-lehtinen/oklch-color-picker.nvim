local utils = require 'oklch-color-picker.utils'

local M = {}

--- @type oklch.FinalPatternList[]
M.patterns = nil
--- @type { enabled: boolean, delay: number }
M.config = nil

local pipe_n = 'oklch-color-picker.sock'
local pipe_name = utils.is_windows() and '\\\\.\\pipe\\' .. pipe_n or '/tmp/' .. pipe_n

--- @type uv_pipe_t|nil
M.pipe = nil

--- @param config { enabled: boolean, delay: number }
--- @param patterns oklch.FinalPatternList[]
function M.setup(config, patterns)
  M.config = config
  M.patterns = patterns

  if not M.config.enabled then
    return
  end

  M.ns = vim.api.nvim_create_namespace 'OklchColorPickerNamespace'
  M.gr = vim.api.nvim_create_augroup('OklchColorPicker', {})

  -- set to false for enable to work
  M.config.enabled = false
  M.enable()
end

function M.disable()
  if not M.config.enabled then
    return
  end
  M.config.enabled = false

  M.bufs = {}
  vim.api.nvim_clear_autocmds { group = M.gr }
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, M.ns, 0, -1)
    end
  end
end

function M.enable()
  if M.config.enabled then
    return
  end
  M.config.enabled = true

  if not M.connected then
    M.connect_pipe_throttled()
  else
    M.on_connected()
  end
  vim.api.nvim_create_autocmd('BufEnter', {
    group = M.gr,
    callback = function(data)
      M.on_buf_enter(data.buf, false)
    end,
  })
end

function M.toggle()
  if M.config.enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.on_connected()
  vim.schedule(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        M.on_buf_enter(bufnr, true)
      end
    end
  end)
end

---@class BufData
---@field pending_changes { from_line: integer, to_line: integer }|nil

--- @type { [integer]: BufData }
M.bufs = {}
--- @type integer
M.ns = nil
--- @type integer
M.gr = nil

--- Unattaching is very annoying, so just make sure we never attach twice
--- @type { [integer]: boolean}
M.buf_attached = {}

--- @param bufnr number
--- @param force_update boolean
function M.on_buf_enter(bufnr, force_update)
  local buftype = vim.api.nvim_get_option_value('buftype', { buf = bufnr })
  if buftype ~= '' then
    return
  end

  if M.bufs[bufnr] then
    if force_update or M.bufs[bufnr].pending_changes then
      M.update(bufnr)
    end
    return
  end

  M.bufs[bufnr] = {
    pending_changes = nil,
  }

  M.update(bufnr)

  if M.buf_attached[bufnr] == nil then
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, _, _, from_line, _, to_line)
        M.update_lines(bufnr, from_line, to_line)
      end,
      on_reload = function()
        M.update(bufnr)
      end,
      on_detach = function()
        M.bufs[bufnr] = nil
        M.buf_attached[bufnr] = nil
      end,
    })
    M.buf_attached[bufnr] = true
  end

  vim.api.nvim_create_autocmd('WinScrolled', {
    group = M.gr,
    buffer = bufnr,
    callback = function(data)
      M.update(data.buf)
    end,
  })
end

--- @param bufnr integer
function M.update(bufnr)
  M.update_lines(bufnr, 0, 100000000)
end

M.pending_timer = vim.uv.new_timer()

--- @param bufnr integer
--- @param from_line integer
--- @param to_line integer
M.update_lines = vim.schedule_wrap(function(bufnr, from_line, to_line)
  local buf_data = M.bufs[bufnr]
  if buf_data == nil then
    return
  end

  if buf_data.pending_changes == nil then
    buf_data.pending_changes = {
      from_line = math.max(from_line, vim.fn.line 'w0' - 1),
      to_line = math.min(to_line, vim.fn.line 'w$'),
    }
  else
    buf_data.pending_changes.from_line = math.max(math.min(buf_data.pending_changes.from_line, from_line), vim.fn.line 'w0' - 1)
    buf_data.pending_changes.to_line = math.min(math.max(buf_data.pending_changes.to_line, to_line), vim.fn.line 'w$')
  end

  M.pending_timer:stop()
  M.pending_timer:start(
    M.config.delay,
    0,
    vim.schedule_wrap(function()
      local buf_data = M.bufs[bufnr]
      if buf_data == nil or buf_data.pending_changes == nil then
        return
      end

      -- local t = vim.uv.hrtime()

      local from_line = buf_data.pending_changes.from_line --[[@as integer]]
      local to_line = buf_data.pending_changes.to_line --[[@as integer]]
      buf_data.pending_changes = nil

      local lines = vim.api.nvim_buf_get_lines(bufnr, from_line, to_line, false)

      local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

      -- ignore very long lines
      for i, line in ipairs(lines) do
        if string.len(line) > 2000 then
          lines[i] = ''
        end
      end

      local matches = {}
      for _, pattern_list in ipairs(M.patterns) do
        if pattern_list.ft(ft) then
          for j, pattern in ipairs(pattern_list) do
            for i, line in ipairs(lines) do
              for match_start, replace_start, replace_end, match_end in line:gmatch(pattern) do
                if type(match_start) ~= 'number' or type(replace_start) ~= 'number' or type(replace_end) ~= 'number' or type(match_end) ~= 'number' then
                  utils.report_invalid_pattern(pattern_list.name, j, pattern)
                  return
                else
                  local line_n = from_line + i
                  if matches[line_n] == nil then
                    matches[line_n] = {}
                  end
                  local has_space = true
                  for _, match in ipairs(matches[line_n]) do
                    if not (match.match_start > match_end or match.match_end < match_start) then
                      has_space = false
                      break
                    end
                  end

                  if has_space then
                    table.insert(matches[line_n], {
                      match_start = match_start,
                      match_end = match_end,
                      color = line:sub(replace_start --[[@as number]], replace_end - 1),
                      color_format = pattern_list.format,
                    })
                  end
                end
              end
            end
          end
        end
      end

      if next(matches) ~= nil then
        M.add_hex_colors(matches)
      end

      M.apply_extmarks(bufnr, from_line, to_line, matches)

      -- local us = (vim.uv.hrtime() - t) / 1000
      -- print(string.format('lines update took: %s us from line %d to %d', us, from_line, to_line))
    end)
  )
end)

function M.apply_extmarks(bufnr, from_line, to_line, matches)
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, M.ns, from_line, to_line)
  for line_n, line_matches in pairs(matches) do
    for _, match in ipairs(line_matches) do
      if match.hex then
        local group = M.compute_hex_color_group(match.hex)
        pcall(
          vim.api.nvim_buf_set_extmark,
          bufnr,
          M.ns,
          line_n - 1,
          match.match_start - 1,
          { priority = 500, end_col = match.match_end - 1, hl_group = group, undo_restore = false }
        )
      end
    end
  end
end

M.hex_color_groups = {}

--- @param hex_color string
--- @return string
function M.compute_hex_color_group(hex_color)
  local cached_group_name = M.hex_color_groups[hex_color]
  if cached_group_name ~= nil then
    return cached_group_name
  end

  local hex = hex_color:sub(2)
  local group_name = string.format('OklchColorPickerHexColor_%s', hex)

  local fg = (M.oklab_lightness(hex) < 0.5) and '#ffffff' or '#000000'
  vim.api.nvim_set_hl(0, group_name, { fg = fg, bg = hex_color })

  M.hex_color_groups[hex_color] = group_name

  return group_name
end

function M.to_linear(c)
  if c <= 0.03928 then
    return c / 12.92
  else
    return math.pow((c + 0.055) / 1.055, 2.4)
  end
end

function M.cbrt(c)
  return math.pow(c, 1 / 3)
end

local k_1 = 0.206
local k_2 = 0.03
local k_3 = (1. + k_1) / (1. + k_2)

--- Perceptual lightness estimate
--- https://bottosson.github.io/posts/colorpicker/#intermission---a-new-lightness-estimate-for-oklab
--- @param hex string
--- @return number
function M.oklab_lightness(hex)
  local number = tonumber(hex, 16)
  local r = bit.rshift(number, 16) / 255
  local g = bit.band(bit.rshift(number, 8), 0xff) / 255
  local b = bit.band(number, 0xff) / 255
  local lr = M.to_linear(r)
  local lg = M.to_linear(g)
  local lb = M.to_linear(b)
  local l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
  local m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
  local s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb
  local l_ = M.cbrt(l)
  local m_ = M.cbrt(m)
  local s_ = M.cbrt(s)
  local ll = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
  return 0.5 * (k_3 * ll - k_1 + math.sqrt((k_3 * ll - k_1) * (k_3 * ll - k_1) + 4 * k_2 * k_3 * ll))
end

--- @type { read: fun(num: number): (string|nil), write: fun(r: string[])}|nil
M.connected = nil

--- @type integer
M.request_counter = 0

--- @param matches {[integer]: {color: string, color_format: string, hex: string|nil|}}
--- @return string|nil
function M.add_hex_colors(matches)
  if not M.connected then
    M.connect_pipe_throttled()
    return nil
  end

  -- local t = vim.uv.hrtime()

  M.request_counter = (M.request_counter + 1) % 1000
  local c = M.request_counter
  local parts = {}
  local line_iter_order = {}
  for line_n, line_matches in pairs(matches) do
    for _, match in ipairs(line_matches) do
      table.insert(parts, (match.color_format or 'auto') .. ';' .. match.color)
    end
    table.insert(line_iter_order, line_n)
  end
  local request = { c .. ':', table.concat(parts, '§§'), '\n' }

  M.connected.write(request)

  local result = M.connected.read(c)
  if not result then
    return nil
  end

  local hexes = vim.split(result, '§§')

  local hex_i = 1

  for _, line_n in ipairs(line_iter_order) do
    for _, match in ipairs(matches[line_n]) do
      local hex = hexes[hex_i]
      if hex:find '^ERR' then
        match.hex = nil
      else
        match.hex = hex
      end
      hex_i = hex_i + 1
    end
  end

  -- local us = (vim.uv.hrtime() - t) / 1000
  -- print('color fetch took: ' .. us .. ' us')
end

M.daemon_started = false

function M.start_daemon()
  if M.daemon_started then
    return
  end

  M.daemon_started = true

  local exec = utils.executable_full_path()
  if exec == nil then
    return
  end

  local cmd
  if utils.is_windows() then
    cmd = { 'powershell', '-WindowStyle', 'Hidden', '-Command', exec .. ' --as-parser-daemon' }
  else
    cmd = { 'sh', '-c', exec .. ' --as-parser-daemon >/dev/null 2>&1 & disown' }
  end

  vim.system(cmd, { detach = true }, function(res)
    if res.code ~= 0 then
      utils.log('App failed and exited with code ' .. res.code, vim.log.levels.ERROR)
    end
    utils.log('App exited successfully with code ' .. vim.inspect(res.code), vim.log.levels.DEBUG)
  end)
  utils.log('Daemon spawned', vim.log.levels.DEBUG)
end

local timeout = 2 * 1000 * 1000 * 1000 -- 2 sec
local read_timeout = 10 * 1000 * 1000 -- 10 ms

local last_connect_try = 0
local connect_try_cooldown = 5 * 1000 * 1000 * 1000 -- 5 secs

function M.connect_pipe_throttled()
  if last_connect_try + connect_try_cooldown > vim.uv.hrtime() then
    return
  end
  utils.log('trying to connect', vim.log.levels.DEBUG)
  last_connect_try = vim.uv.hrtime()
  M.connect_pipe()
end

--- @param start_time number|nil
function M.connect_pipe(start_time)
  if not start_time then
    start_time = vim.loop.hrtime()
    M.daemon_started = false
  end

  if vim.uv.hrtime() - start_time > timeout then
    utils.log('Connection timed out', vim.log.levels.ERROR)
    return
  end

  if M.pipe ~= nil and not M.pipe:is_closing() then
    M.pipe:close()
  end
  M.pipe = vim.uv.new_pipe(true)

  local on_connect = function(connect_err)
    local retry = function(err)
      utils.log("couldn't connect: " .. err, vim.log.levels.DEBUG)

      M.start_daemon()

      vim.defer_fn(function()
        M.connect_pipe(start_time)
      end, 40)
    end

    if connect_err then
      retry(connect_err)
      return
    end

    local verified = nil
    M.pipe:write('test\n', function(err)
      verified = not err
    end)

    while verified == nil do
      vim.uv.run 'nowait'
    end

    if not verified then
      retry 'broken pipe'
      return
    end

    utils.log('connected', vim.log.levels.DEBUG)

    local read_result = {}
    local read_total = ''
    local on_read = function(err, data)
      if data then
        read_total = read_total .. data
        local i1 = read_total:find '\n'
        while i1 do
          local part = read_total:sub(1, i1 - 1)
          read_total = read_total:sub(i1 + 1)
          local number, text = part:match '(%d+):(.*)'
          if number then
            read_result[tonumber(number)] = text
          end
          i1 = read_total:find '\n'
        end
      elseif err then
        if err ~= 'ECONNRESET' then
          utils.log('Receive error: ' .. err, vim.log.levels.ERROR)
          vim.schedule(function()
            M.connected = nil
            M.pipe:close()
          end)
        end
      end
    end

    M.pipe:read_start(on_read)

    M.connected = {
      read = function(number)
        local nkey = number
        local t = vim.uv.hrtime()
        while read_result[nkey] == nil and vim.uv.hrtime() - t < read_timeout do
          vim.uv.run 'nowait'
        end
        local res = read_result[nkey]
        read_result[nkey] = nil
        -- local us = (vim.uv.hrtime() - t) / 1000
        -- print('read took: ' .. us .. ' us')
        return res
      end,
      write = function(data)
        M.pipe:write(data, function(err)
          if err then
            if err == 'EPIPE' then
              utils.log('Daemon was closed for some reason', vim.log.levels.INFO)
            else
              utils.log('Send error: ' .. err, vim.log.levels.ERROR)
            end
            vim.schedule(function()
              M.connected = nil
              M.pipe:close()
            end)
          end
        end)
      end,
    }

    M.on_connected()
  end

  local _, err_name, err_message = M.pipe:connect(pipe_name, on_connect)
  if err_name then
    utils.log('Failed to start pipe: ' .. err_name .. ' ' .. err_message, vim.log.levels.ERROR)
  end
end

return M
