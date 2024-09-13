local download = require("oklch-color-picker.download")
local utils = require("oklch-color-picker.utils")

local M = {}

M.download_picker_app = download.download_picker_app

M.default_config = {
	log_level = vim.log.levels.INFO,
}

function M.setup(config)
	M.config = vim.tbl_deep_extend("force", M.default_config, config or {})
	utils.setup(M.config)
end

local pending_edit = nil

local function apply_new_color(color)
	if not pending_edit then
		utils.log("Don't call apply_new_color if there is no pending edit!!!", vim.log.levels.DEBUG)
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

local path = nil
local make_path = function()
	if path ~= nil then
		return path
	end
	local path_sep = utils.is_windows() and ";" or ":"
	path = utils.root_path() .. "/app" .. path_sep .. os.getenv("PATH")
	return path
end

local function start_app()
	if not pending_edit then
		utils.log("Can't start app, no pending edit", vim.log.levels.WARN)
		return
	end
	path = make_path()

	local res = vim.system({ utils.executable(), pending_edit.color }, { env = { PATH = path } }):wait()

	if res.code ~= 0 then
		utils.log(res.stderr, vim.log.levels.ERROR)
		return
	end

	utils.log("Picker success " .. res.stdout, vim.log.levels.DEBUG)

	if res.stdout == "" then
		utils.log("Picker returned an empty string", vim.log.levels.WARN)
		return
	end

	local color = res.stdout:match("^[^\r\n]*")
	apply_new_color(color)
end

local function find_color(line, cursor_col)
	local patterns = {
		"()#%x%x%x%x%x%x%x%x()",
		"()#%x%x%x%x%x%x()",
		"()#%x%x%x%x()",
		"()#%x%x%x()",
		"()rgb%(.*%)()",
		"()oklch%(.*%)()",
		"()hsl%(.*%)()",
		"%(().*()%)",
	}

	for _, pattern in ipairs(patterns) do
		for start_pos, end_pos in line:gmatch(pattern) do
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
		utils.log("No color under cursor", vim.log.levels.INFO)
		return
	end

	utils.log("Found color at position " .. vim.inspect(pos) .. " with color " .. color, vim.log.levels.DEBUG)

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
