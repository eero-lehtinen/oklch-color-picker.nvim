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

  if not config.enabled then
    return
  end

  M.ns = vim.api.nvim_create_namespace 'OklchColorPickerNamespace'
  M.gr = vim.api.nvim_create_augroup('OklchColorPicker', {})

  M.enable()
end

function M.disable()
  M.bufs = {}
  vim.api.nvim_clear_autocmds { group = M.gr }
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, M.ns, 0, -1)
    end
  end
end

function M.enable()
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

function M.on_connected()
  vim.schedule(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        M.on_buf_enter(bufnr, true)
      end
    end
  end)
end

--- @type { [integer]: { pending_changes: { from_line: integer, to_line: integer }|nil } }
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
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, M.ns, from_line, to_line)

      local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

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
                { priority = 500, end_col = match.match_end - 1, hl_group = group }
              )
            end
          end
        end
      end

      -- local us = (vim.uv.hrtime() - t) / 1000
      -- print(string.format('lines update took: %s us from line %d to %d', us, from_line, to_line))
    end)
  )
end)

M.hex_color_groups = {}

--- @param hex_color string
--- @return string
function M.compute_hex_color_group(hex_color)
  local hex = hex_color:lower():sub(2)
  local group_name = string.format('OklchColorPickerHexColor_%s', hex)

  if M.hex_color_groups[group_name] then
    return group_name
  end

  local opposite = M.compute_opposite_color(hex)
  vim.api.nvim_set_hl(0, group_name, { fg = opposite, bg = hex_color })

  M.hex_color_groups[group_name] = true

  return group_name
end

--- @param hex string
--- @return string
function M.compute_opposite_color(hex)
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  return (0.299 * r + 0.587 * g + 0.114 * b) < 0.5 and '#ffffff' or '#000000'
end

--- @type { read: fun(number): (string|nil), write: fun(string)}|nil
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
  M.connected.write(string.format('%d:%s\n', c, table.concat(parts, '¿¿')))

  local result = M.connected.read(c)
  if not result then
    return nil
  end

  local hexes = vim.split(result, '¿¿')

  local hex_i = 1

  for _, line_n in ipairs(line_iter_order) do
    for _, match in ipairs(matches[line_n]) do
      local hex = hexes[hex_i]
      if hex:find '^ERR' then
        match.hex = nil
      else
        -- Remove alpha if it's there
        if #hex == 9 then
          hex = hex:sub(1, -3)
        end
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

  local exec
  if vim.fn.executable(utils.executable()) == 1 then
    exec = utils.executable()
  else
    exec = utils.get_path() .. utils.executable()
  end

  local cmd = exec .. ' --as-parser-daemon >/dev/null 2>&1 & disown'

  vim.system({ 'sh', '-c', cmd }, {
    detach = true,
  }, function(res)
    if res.code ~= 0 then
      utils.log('App failed and exited with code ' .. res.code, vim.log.levels.ERROR)
    end
    utils.log('App exited successfully with code ' .. vim.inspect(res.code), vim.log.levels.DEBUG)
  end)
  utils.log('Daemon spawned', vim.log.levels.DEBUG)
end

local timeout = 200 * 1000 * 1000 -- 200 ms
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
    utils.log('timed out', vim.log.levels.ERROR)
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
      end, 20)
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
          utils.log('receive error: ' .. err, vim.log.levels.ERROR)
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
              utils.log('daemon was closed for some reason', vim.log.levels.INFO)
            else
              utils.log('send error: ' .. err, vim.log.levels.ERROR)
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
    utils.log('failed to start pipe: ' .. err_name .. ' ' .. err_message, vim.log.levels.ERROR)
  end
end

return M
