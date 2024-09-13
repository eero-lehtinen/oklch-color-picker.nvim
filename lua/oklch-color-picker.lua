local M = {}

M.config = {
	log_level = vim.log.levels.INFO,
}

local function lua_path()
	return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
end

function M.setup(config)
	M.config = vim.tbl_deep_extend("force", M.config, config or {})
	vim.opt.path:append(lua_path() .. "../app")
end

local uv = vim.uv

local pending_edit = nil

local function log(msg, level)
	if level >= M.config.log_level then
		vim.schedule(function()
			vim.notify("oklch-color-picker: " .. msg, level)
		end)
	end
end

local function is_windows()
	return vim.loop.os_uname().sysname:find("Windows")
end

local function executable()
	local executable_ext = is_windows() and ".exe" or ""
	return "oklch-color-picker" .. executable_ext
end

function M.download_picker_app()
	local version = "1.0.0"
	local platform
	local archive_ext
	local sysname = vim.loop.os_uname().sysname
	if sysname == "Linux" then
		platform = "x86_64-unknown-linux-gnu"
		archive_ext = ".tar.gz"
	elseif sysname == "Darwin" then
		platform = "x86_64-apple-darwin"
		archive_ext = ".tar.gz"
	elseif sysname:find("Windows") then
		platform = "x86_64-pc-windows-gnu"
		archive_ext = ".zip"
	else
		log("Unsupported platform: " .. sysname, vim.log.levels.ERROR)
		return
	end

	local archive_basename = "oklch-color-picker-" .. version .. "-" .. platform
	local archive = archive_basename .. archive_ext

	local url = "https://github.com/eero-lehtinen/oklch-color-picker/releases/download/" .. version .. "/" .. archive

	local cwd = lua_path() .. ".."

	log("Downloading picker from " .. url, vim.log.levels.INFO)

	uv.spawn("curl", { args = {
		"-L",
		"-o",
		archive,
		url,
	}, cwd = cwd }, function(code)
		if code ~= 0 then
			log("Curl failed with code " .. code, vim.log.levels.ERROR)
			return
		end
		log("Download success, extracting", vim.log.levels.INFO)

		local on_extract = function(code)
			if code ~= 0 then
				log("Extraction failed with code " .. code, vim.log.levels.ERROR)
				return
			end

			os.remove(cwd .. "/" .. archive)
			os.remove(cwd .. "/app/" + executable())
			os.remove(cwd .. "/app")
			local success, err = os.rename(cwd .. "/" .. archive_basename, cwd .. "/app")
			if not success then
				log("Failed to rename archive to app: " .. err, vim.log.levels.ERROR)
				return
			end

			log("Extraction success", vim.log.levels.INFO)
		end

		if is_windows() then
			uv.spawn(
				"powershell",
				{ args = { "-command", "Expand-Archive", "-Path", archive, "-DestinationPath", "." }, cwd = cwd },
				on_extract
			)
		else
			uv.spawn("tar", { args = { "xzf", archive }, cwd = cwd }, on_extract)
		end
	end)
end

local function apply_new_color(color)
	if not pending_edit then
		log("Don't call apply_new_color if there is no pending edit!!!", vim.log.levels.DEBUG)
		return
	end

	vim.schedule(function()
		vim.api.nvim_buf_set_text(
			pending_edit.bufnr,
			pending_edit.line_number - 1,
			pending_edit.start - 1,
			pending_edit.line_number - 1,
			pending_edit.finish,
			{ color }
		)
		pending_edit = nil
	end)
end

local function start_app()
	if not pending_edit then
		log("Can't start app, no pending edit", vim.log.levels.WARN)
		return
	end

	local stdout = uv.new_pipe()
	local stderr = uv.new_pipe()

	uv.spawn(executable(), { args = { pending_edit.color }, stdio = { nil, stdout, stderr } }, function(code)
		if code ~= 0 then
			log("App closed: exit_code " .. code, vim.log.levels.DEBUG)
			return
		end
	end)

	local on_stdout = function(err, data)
		if data then
			log("App stdout: " .. data, vim.log.levels.DEBUG)
			apply_new_color(data)
			stdout:read_stop()
			stderr:read_stop()
		elseif err then
			log("App stdout error: " .. err, vim.log.levels.DEBUG)
		else
			log("App stdout closed", vim.log.levels.DEBUG)
		end
	end

	local on_stderr = function(err, data)
		if data then
			log(data, vim.log.levels.ERROR)
		elseif err then
			log("App stderr error: " .. err, vim.log.levels.DEBUG)
		else
			log("App stderr closed", vim.log.levels.DEBUG)
		end
	end

	stdout:read_start(on_stdout)
	stderr:read_start(on_stderr)
end

local function find_color(line, cursor_col)
	local patterns = {
		"#%x%x%x%x%x%x%x%x", -- #RRGGBBAA
		"#%x%x%x%x%x%x", -- #RRGGBB
		"#%x%x%x%x", -- #RGBA
		"#%x%x%x", -- #RGB
	}

	for _, pattern in ipairs(patterns) do
		for start_pos, end_pos in line:gmatch("()" .. pattern .. "()") do
			if cursor_col >= start_pos and cursor_col <= end_pos - 1 then
				return { start_pos, end_pos - 1 }, line:sub(start_pos, end_pos - 1)
			end
		end
	end

	return nil, nil
end

function M.pick_color_under_cursor()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local row = cursor_pos[1]
	local col = cursor_pos[2] + 1

	local bufnr = vim.api.nvim_get_current_buf()

	local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]

	local pos, color = find_color(line, col)

	if not pos or not color then
		log("No color under cursor", vim.log.levels.INFO)
		return
	end

	log("Found color at position " .. vim.inspect(pos) .. " with color " .. color, vim.log.levels.DEBUG)

	pending_edit = {
		bufnr = bufnr,
		line_number = row,
		start = pos[1],
		finish = pos[2],
		color = color,
	}

	start_app()
end

return M
