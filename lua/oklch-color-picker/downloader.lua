local utils = require("oklch-color-picker.utils")

local version = "1.14.1"

local github_url = "https://github.com/eero-lehtinen/oklch-color-picker/releases/download/" .. version .. "/"

local M = {}

---@param callback fun(err: string|nil)
function M.ensure_app_downloaded(callback)
  M.validate_app_version(vim.schedule_wrap(function(correct_app_version)
    if correct_app_version then
      callback(nil)
      return
    end

    M.download_app(function(err)
      if err then
        callback("Couldn't download picker app: " .. err)
        return
      end
      utils.exec = nil
      callback(nil)
    end)
  end))
end

---@param callback fun(valid: boolean)
function M.validate_app_version(callback)
  local exec = utils.executable_full_path()
  if not exec then
    callback(false)
    return
  end
  vim.system({ exec, "--version" }, {}, function(out)
    if out.code ~= 0 then
      callback(false)
      return
    end
    callback(out.stdout:find(version) ~= nil)
  end)
end

---@param callback fun(err: string|nil)
function M.ensure_parser_downloaded(callback)
  if M.validate_parser_version() then
    callback(nil)
    return
  end

  M.download_parser(function(err)
    if err then
      callback("Couldn't download parser library: " .. err)
      return
    end
    callback(nil)
  end)
end

---@return boolean
function M.validate_parser_version()
  local parser = require("oklch-color-picker.parser").get_parser()
  local result = parser ~= nil and parser.version():find(version)
  if not result then
    package.loaded["parser_lua_module"] = nil
  end
  return result
end

---@param kind 'lib'|'app'
---@return string, string
function M.get_target_info(kind)
  if utils.is_macos() then
    return utils.arch() .. "-apple-darwin", ".tar.gz"
  elseif utils.is_windows() or (kind == "app" and utils.is_wsl()) then
    return "x86_64-pc-windows-msvc", ".zip"
  else
    return "x86_64-unknown-linux-gnu", ".tar.gz"
  end
end

---@param callback fun(err: string|nil)
function M.download_app(callback)
  local platform, archive_ext = M.get_target_info("app")

  local archive_basename = "oklch-color-picker-" .. version .. "-" .. platform
  local archive = archive_basename .. archive_ext

  local url = github_url .. archive

  local cwd = utils.get_path()

  utils.log("Downloading picker app...", vim.log.levels.INFO)

  if vim.fn.executable("curl") ~= 1 then
    callback("'curl' not found, please install it")
    return
  end

  vim.system(
    { "curl", "--fail", "-o", archive, "-L", url },
    { cwd = cwd },
    vim.schedule_wrap(function(out)
      if out.code ~= 0 then
        callback("Curl failed\nstdout: " .. out.stdout .. "\nstderr: " .. out.stderr)
        return
      end

      utils.log("Download success, extracting", vim.log.levels.DEBUG)

      local on_extracted = vim.schedule_wrap(function(out2)
        if out2.code ~= 0 then
          callback("Extraction failed\nstdout: " .. out2.stdout .. "\nstderr: " .. out2.stderr)
          return
        end

        os.remove(cwd .. "/" .. archive)
        os.remove(cwd .. "/" .. utils.executable())
        os.rename(cwd .. "/" .. archive_basename .. "/" .. utils.executable(), cwd .. "/" .. utils.executable())
        os.remove(cwd .. "/" .. archive_basename)

        utils.log("Extraction success, binary in " .. cwd, vim.log.levels.DEBUG)
        utils.log("Picker app downloaded", vim.log.levels.INFO)
        callback(nil)
      end)

      if utils.is_windows() then
        vim.system(
          { "powershell", "-command", "Expand-Archive", "-Path", archive, "-DestinationPath", "." },
          { cwd = cwd },
          on_extracted
        )
      elseif utils.is_wsl() then
        if vim.fn.executable("unzip") ~= 1 then
          callback("'unzip' not found, please install it")
          return
        end
        vim.system({ "unzip", archive }, { cwd = cwd }, on_extracted)
      else
        if vim.fn.executable("tar") ~= 1 then
          callback("'tar' not found, please install it")
          return
        end
        vim.system({ "tar", "xzf", archive }, { cwd = cwd }, on_extracted)
      end
    end)
  )
end

---@param callback fun(err: string|nil)
function M.download_parser(callback)
  local platform, _ = M.get_target_info("lib")
  local lib_ext = utils.get_lib_extension()

  local lib = "parser_lua_module-" .. platform .. lib_ext
  local url = github_url .. lib

  local cwd = utils.get_path()

  utils.log("Downloading parser...", vim.log.levels.INFO)

  local out_lib = "parser_lua_module" .. lib_ext

  if vim.fn.executable("curl") ~= 1 then
    callback("'curl' not found, please install it")
    return
  end

  vim.system(
    { "curl", "--fail", "-o", out_lib, "-L", url },
    { cwd = cwd },
    vim.schedule_wrap(function(out)
      if out.code ~= 0 then
        callback("Curl failed\nstdout: " .. out.stdout .. "\nstderr: " .. out.stderr)
        return
      end

      utils.log("Parser located at " .. cwd, vim.log.levels.DEBUG)
      utils.log("Parser downloaded", vim.log.levels.INFO)
      callback(nil)
    end)
  )
end

return M
