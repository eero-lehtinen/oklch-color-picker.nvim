local utils = require("oklch-color-picker.utils")

---@class oklch
local M = {}

---@alias oklch.PatternList { [number]: string, format: string|nil, ft: string[]|nil }

---@class oklch.Config
local default_config = {
	---@type integer
	log_level = vim.log.levels.INFO,
	---@type { css: oklch.PatternList, numbers_in_brackets: oklch.PatternList }
	patterns = {
		hex = {
			"()#%x%x%x%x%x%x%x%x()",
			"()#%x%x%x%x%x%x()",
			"()#%x%x%x%x()",
			"()#%x%x%x()",
		},
		css = {
			"()rgb%(.*%)()",
			"()oklch%(.*%)()",
			"()hsl%(.*%)()",
		},
		numbers_in_brackets = { "%(()[%d.,%s]*()%)" },
	},
	---@type { [string]: oklch.PatternList }
	custom_patterns = {},
}

---@type oklch.Config
M.config = {}

---@param config oklch.Config
function M.setup(config)
	M.config = vim.tbl_deep_extend("force", default_config, config or {})
	utils.setup(M.config)
end

--- @alias oklch.PendingEdit { bufnr: number, changedtick: number, line_number: number, start: number, finish: number, color: string, color_format: string|nil }|nil

--- @type oklch.PendingEdit
local pending_edit = nil

---@param color string
local function apply_new_color(color)
	if not pending_edit then
		utils.log("Don't call apply_new_color if there is no pending edit!!!", vim.log.levels.DEBUG)
		return
	end

	vim.schedule(function()
		if pending_edit.changedtick ~= vim.api.nvim_buf_get_changedtick(pending_edit.bufnr) then
			utils.log("Not applying new color '" .. color .. "' because the buffer has changed", vim.log.levels.WARN)
			return
		end

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

---@type string|nil
local path = nil

---@return string
local function make_path()
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

	local stdout = function(err, data)
		if data then
			utils.log("Stdout: " .. data, vim.log.levels.DEBUG)
			if data == "" then
				utils.log("Picker returned an empty string", vim.log.levels.WARN)
				return
			end
			local color = data:match("^[^\r\n]*")
			apply_new_color(color)
		elseif err then
			utils.log("Stdout error: " .. err, vim.log.levels.DEBUG)
		else
			utils.log("Stdout closed", vim.log.levels.DEBUG)
		end
	end

	local stderr = function(err, data)
		if data then
			utils.log(data:match("^[^\r\n]*"), vim.log.levels.WARN)
		elseif err then
			utils.log("Stderr error: " .. err, vim.log.levels.DEBUG)
		else
			utils.log("Stderr closed", vim.log.levels.DEBUG)
		end
	end

	local cmd = { utils.executable(), pending_edit.color }
	if pending_edit.color_format then
		table.insert(cmd, "--format")
		table.insert(cmd, pending_edit.color_format)
	end

	vim.system(cmd, { env = { PATH = path }, stdout = stdout, stderr = stderr }, function(res)
		if res.code ~= 0 then
			utils.log("App failed and exited with code " .. res.code, vim.log.levels.DEBUG)
		end
		utils.log("App exited successfully " .. vim.inspect(res), vim.log.levels.DEBUG)
	end)
end

--- @param line string
--- @param cursor_col number
--- @param ft string|nil
--- @return { pos: [number, number], color: string, color_format: string|nil }| nil
local function find_color(line, cursor_col, ft)
	for _, patterns in ipairs({ M.config.custom_patterns, M.config.patterns }) do
		for key, pattern_list in pairs(patterns) do
			if pattern_list and (not pattern_list.ft or (ft and vim.tbl_contains(pattern_list.ft, ft))) then
				for i, pattern in ipairs(pattern_list) do
					for start_pos, end_pos in line:gmatch(pattern) do
						if type(start_pos) ~= "number" then
							utils.log(
								"Pattern "
									.. key
									.. "["
									.. i
									.. "] = '"
									.. pattern
									.. "' is invalid. It should contain two empty '()' groups to designate the replacement range and no other groups. Remember to escape literal brackets: '%(' or '%)'",
								vim.log.levels.ERROR
							)
							return nil
						else
							if cursor_col >= start_pos and cursor_col <= end_pos - 1 then
								return {
									pos = { start_pos, end_pos - 1 },
									color = line:sub(start_pos --[[@as number]], end_pos - 1),
									color_format = pattern_list.format,
								}
							end
						end
					end
				end
			end
		end
	end

	return nil
end

function M.pick_under_cursor()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local row = cursor_pos[1]
	local col = cursor_pos[2] + 1

	local bufnr = vim.api.nvim_get_current_buf()

	local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
	local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")

	local res = find_color(line, col, ft)

	if not res then
		utils.log("No color under cursor", vim.log.levels.INFO)
		return
	end

	utils.log("Found color " .. res.color .. "at position " .. vim.inspect(res.pos), vim.log.levels.DEBUG)

	pending_edit = {
		bufnr = bufnr,
		changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
		line_number = row,
		start = res.pos[1],
		finish = res.pos[2],
		color = res.color,
		color_format = res.color_format,
	}

	start_app()
end

return M
