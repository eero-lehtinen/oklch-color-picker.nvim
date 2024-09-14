local utils = require("oklch-color-picker.utils")

---@class oklch
local M = {}

---@alias oklch.PatternList { name: string|nil, format: string|nil, ft: string[]|nil, [number]: string,  }

---@class oklch.Config
local default_config = {
	---@type integer
	log_level = vim.log.levels.INFO,
	---@type oklch.PatternList[]
	default_patterns = {
		{
			name = "hex",
			"()#%x%x%x%x%x%x%x%x()",
			"()#%x%x%x%x%x%x()",
			"()#%x%x%x%x()",
			"()#%x%x%x()",
		},
		{
			name = "css",
			"()rgb%(.*%)()",
			"()oklch%(.*%)()",
			"()hsl%(.*%)()",
		},
		{
			name = "numbers_in_brackets",
			"%(()[%d.,%s]*()%)",
		},
	},
	---@type string[]
	disable_default_patterns = {},
	---@type oklch.PatternList[]
	custom_patterns = {},
}

---@type oklch.Config
M.config = {}

---@param config oklch.Config
function M.setup(config)
	M.config = vim.tbl_deep_extend("force", default_config, config or {})
	utils.setup(M.config)

	for _, name in ipairs(M.config.disable_default_patterns) do
		for i = #M.config.default_patterns, 1, -1 do
			if M.config.default_patterns[i].name == name then
				table.remove(M.config.default_patterns, i)
			end
		end
	end

	for _, patterns in ipairs({ M.config.default_patterns, M.config.custom_patterns }) do
		for _, pattern_list in ipairs(patterns) do
			for i = 1, #pattern_list do
				pattern_list[i] = "()" .. pattern_list[i] .. "()"
			end
		end
	end
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
	for _, patterns in ipairs({ M.config.custom_patterns, M.config.default_patterns }) do
		for _, pattern_list in ipairs(patterns) do
			if pattern_list and (not pattern_list.ft or (ft and vim.tbl_contains(pattern_list.ft, ft))) then
				for i, pattern in ipairs(pattern_list) do
					for match_start, replace_start, replace_end, match_end in line:gmatch(pattern) do
						if type(replace_start) ~= "number" then
							utils.log(
								"Pattern "
									.. (pattern_list.name or "unnamed")
									.. "["
									.. i
									.. "] = '"
									.. pattern
									.. "' is invalid. It should contain two empty '()' groups to designate the replacement range and no other groups. Remember to escape literal brackets: '%(' or '%)'",
								vim.log.levels.ERROR
							)
							return nil
						else
							if cursor_col >= match_start and cursor_col <= match_end - 1 then
								return {
									pos = { replace_start, replace_end - 1 },
									color = line:sub(replace_start --[[@as number]], replace_end - 1),
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

--- @param force_color_format string|nil
function M.pick_under_cursor(force_color_format)
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
		color_format = force_color_format or res.color_format,
	}

	start_app()
end

return M
