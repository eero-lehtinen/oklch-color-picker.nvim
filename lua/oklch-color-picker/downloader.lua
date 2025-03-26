local utils = require("oklch-color-picker.utils")

local version = "2.1.0"

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
  M.validate_parser_version(vim.schedule_wrap(function(correct_parser_version)
    if correct_parser_version then
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
  end))
end

---@param callback fun(valid: boolean)
function M.validate_parser_version(callback)
  vim.uv.fs_open(utils.get_path() .. "/parser_version", "r", 438, function(err, fd)
    if err or not fd then
      utils.log(err or "", vim.log.levels.DEBUG)
      return callback(false)
    end

    vim.uv.fs_read(fd, 1024, 0, function(read_err, data)
      vim.uv.fs_close(fd)
      return callback(not read_err and data == version)
    end)
  end)
end

function M.write_parser_version()
  vim.uv.fs_open(utils.get_path() .. "/parser_version", "w", 438, function(err, fd)
    if err or not fd then
      utils.log(function()
        return "Couldn't open version file for writing: " .. (err or "")
      end, vim.log.levels.WARN)
      return
    end

    vim.uv.fs_write(fd, version, 0, function(write_err)
      vim.uv.fs_close(fd)
      if write_err then
        utils.log(function()
          return "Couldn't write version file:" .. write_err
        end, vim.log.levels.WARN)
      end
    end)
  end)
end

---@param kind 'lib'|'app'
---@return string|nil, string, string
function M.get_target_info(kind)
  if vim.fn.has("android") == 1 then
    return "Android not currently supported", "", ""
  end

  local rust_arch = nil
  if jit.arch == "arm64" then
    rust_arch = "aarch64"
  elseif jit.arch == "x64" then
    rust_arch = "x86_64"
  end

  if jit.os == "OSX" and rust_arch then
    return nil, rust_arch .. "-apple-darwin", ".tar.gz"
  elseif (jit.os == "Windows" or (kind == "app" and utils.is_wsl())) and rust_arch == "x86_64" then
    return nil, "x86_64-pc-windows-msvc", ".zip"
  elseif jit.os == "Linux" and rust_arch == "x86_64" then
    return nil, "x86_64-unknown-linux-gnu", ".tar.gz"
  else
    return string.format("Platform (%s - %s) not currently supported", jit.os, jit.arch), "", ""
  end
end

---@param callback fun(err: string|nil)
function M.download_app(callback)
  local error, platform, archive_ext = M.get_target_info("app")
  if error then
    callback(error)
    return
  end

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
        local success, err = vim.uv.fs_rename(
          cwd .. "/" .. archive_basename .. "/" .. utils.executable(),
          cwd .. "/" .. utils.executable()
        )
        if err or not success then
          if utils.is_windows() then
            utils.log("You likely have the picker app open somewhere. Close it and try again.", vim.log.levels.WARN)
          end
          callback("Picker app rename after download failed: " .. err)
          return
        end

        os.remove(cwd .. "/" .. archive_basename)

        utils.log(function()
          return "Extraction success, binary in " .. cwd
        end, vim.log.levels.DEBUG)
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
  local error, platform, _ = M.get_target_info("lib")
  if error then
    callback(error)
    return
  end

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

  -- Download to a temporary file to avoid crashing:
  -- https://developer.apple.com/documentation/security/updating-mac-software
  vim.system(
    { "curl", "--fail", "-o", out_lib .. ".tmp", "-L", url },
    { cwd = cwd },
    vim.schedule_wrap(function(out)
      if out.code ~= 0 then
        callback("Curl failed\nstdout: " .. out.stdout .. "\nstderr: " .. out.stderr)
        return
      end

      local success, err = vim.uv.fs_rename(cwd .. "/" .. out_lib .. ".tmp", cwd .. "/" .. out_lib)
      if err or not success then
        if utils.is_windows() then
          utils.log(
            "You likely have other Neovim instances open and using the library. Close them and try again.",
            vim.log.levels.WARN
          )
        end
        callback("Parser rename after download failed: " .. err)
        return
      end

      M.write_parser_version()

      utils.log(function()
        return "Parser located at " .. cwd
      end, vim.log.levels.DEBUG)
      utils.log("Parser downloaded", vim.log.levels.INFO)
      callback(nil)
    end)
  )
end

return M
