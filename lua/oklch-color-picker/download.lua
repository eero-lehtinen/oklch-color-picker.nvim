local utils = require("oklch-color-picker.utils")

local M = {}

function M.download_picker_app()
	local log_status = coroutine.running()
			and function(msg, level)
				coroutine.yield({ msg = msg, level = level })
			end
		or utils.log
	-- local log_status = utils.log

	local version = "1.0.1"
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
		log_status("Unsupported platform: " .. sysname, vim.log.levels.ERROR)
		return
	end

	local archive_basename = "oklch-color-picker-" .. version .. "-" .. platform
	local archive = archive_basename .. archive_ext

	local url = "https://github.com/eero-lehtinen/oklch-color-picker/releases/download/" .. version .. "/" .. archive

	local cwd = utils.root_path()

	log_status("Downloading picker from " .. url, vim.log.levels.INFO)

	local res = vim.system({ "curl", "-o", archive, "-L", url }, { cwd = cwd }):wait()
	if res.code ~= 0 then
		log_status("Curl failed\nstdout: " .. res.stdout .. "\nstderr: " .. res.stderr, vim.log.levels.ERROR)
		return
	end

	log_status("Download success, extracting", vim.log.levels.INFO)

	if utils.is_windows() then
		res = vim.system(
			{ "powershell", "-command", "Expand-Archive", "-Path", archive, "-DestinationPath", "." },
			{ cwd = cwd }
		)
			:wait()
	else
		res = vim.system({ "tar", "xzf", archive }, { cwd = cwd }):wait()
	end

	if res.code ~= 0 then
		log_status("Extraction failed\nstdout: " .. res.stdout .. "\nstderr: " .. res.stderr, vim.log.levels.ERROR)
		return
	end

	os.remove(cwd .. "/" .. archive)
	os.remove(cwd .. "/app/" .. utils.executable())
	os.remove(cwd .. "/app")
	local success, err = os.rename(cwd .. "/" .. archive_basename, cwd .. "/app")
	if not success then
		log_status("Failed to rename archive to app: " .. err, vim.log.levels.ERROR)
		return
	end

	log_status("Extraction success", vim.log.levels.INFO)
end

return M
