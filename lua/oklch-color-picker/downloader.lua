local utils = require("oklch-color-picker.utils")

local version = "2.3.1"

local github_url = "https://github.com/eero-lehtinen/oklch-color-picker/releases/download/" .. version .. "/"

local M = {}

---@param callback fun(err: string|nil)
function M.ensure_app_downloaded(callback)
  M.validate_app_version(vim.schedule_wrap(function(err)
    if not err then
      callback(nil)
      return
    end

    -- This error is not fatal, we just need to download the app.
    utils.log(err, vim.log.levels.INFO)

    M.download_app(function(err2)
      if err2 then
        callback("Couldn't download picker app: " .. err2)
        return
      end
      utils.exec = nil
      callback(nil)
    end)
  end))
end

---@param callback fun(err: string?)
function M.validate_app_version(callback)
  local err, exec = utils.executable_full_path()
  if err then
    callback(err)
    return
  end
  vim.system({ exec, "--version" }, {}, function(out)
    if out.code ~= 0 then
      callback("Picker app failed to run\nstdout: " .. out.stdout .. "\nstderr: " .. out.stderr)
      return
    end
    if out.stdout:find(version) then
      callback(nil)
    else
      callback("Picker app version mismatch: expected " .. version .. ", got " .. out.stdout:match("[%d%.]+"))
    end
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
  elseif (jit.os == "Windows" or (kind == "app" and utils.is_wsl_and_use_exe())) and rust_arch then
    return nil, rust_arch .. "-pc-windows-msvc", ".zip"
  elseif jit.os == "Linux" and rust_arch then
    return nil, rust_arch .. "-unknown-linux-gnu", ".tar.gz"
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

  local err = utils.system(
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

        vim.uv.fs_unlink(cwd .. "/" .. archive)
        local success, rename_err = vim.uv.fs_rename(
          cwd .. "/" .. archive_basename .. "/" .. utils.executable(),
          cwd .. "/" .. utils.executable()
        )
        if rename_err or not success then
          if utils.is_windows() then
            rename_err = "\n\nYou likely have the picker app open somewhere. Close it and try again.\n\n" .. rename_err
          end
          callback("Picker app rename after download failed: " .. rename_err)
          return
        end

        if utils.is_wsl_and_use_exe() then
          -- Zip files extracted in WSL don't have execute permissions by default.
          vim.uv.fs_chmod(cwd .. "/" .. utils.executable(), 493) -- 0755 in octal
        end

        vim.fn.delete(cwd .. "/" .. archive_basename, "rf")

        utils.log(function()
          return "Picker app v" .. version .. " downloaded to " .. cwd .. "/" .. utils.executable()
        end, vim.log.levels.INFO)

        callback(nil)
      end)

      local extract_cmd
      if archive_ext == ".zip" then
        if vim.fn.executable("unzip") == 1 then
          extract_cmd = { "unzip", archive }
        else
          utils.log("'unzip' not found, falling back to 'tar'", vim.log.levels.WARN)
          extract_cmd = { "tar", "xf", archive }
        end
      else
        extract_cmd = { "tar", "xf", archive }
      end

      local extract_err = utils.system(extract_cmd, { cwd = cwd }, on_extracted)
      if extract_err then
        callback(extract_err)
      end
    end)
  )
  if err then
    callback(err)
  end
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

  -- Download to a temporary file to avoid crashing:
  -- https://developer.apple.com/documentation/security/updating-mac-software
  local err = utils.system(
    { "curl", "--fail", "-o", out_lib .. ".tmp", "-L", url },
    { cwd = cwd },
    vim.schedule_wrap(function(out)
      if out.code ~= 0 then
        callback("Curl failed\nstdout: " .. out.stdout .. "\nstderr: " .. out.stderr)
        return
      end

      local success, rename_err = vim.uv.fs_rename(cwd .. "/" .. out_lib .. ".tmp", cwd .. "/" .. out_lib)
      if rename_err or not success then
        if utils.is_windows() then
          rename_err = "\n\nYou likely have another Nvim instance using the library. Close it and try again.\n\n"
            .. rename_err
        end
        callback("Parser rename after download failed: " .. rename_err)
        return
      end

      M.write_parser_version()

      utils.log(function()
        return "Parser v" .. version .. " downloaded to " .. cwd .. "/" .. out_lib
      end, vim.log.levels.INFO)
      callback(nil)
    end)
  )
  if err then
    callback(err)
  end
end

return M
