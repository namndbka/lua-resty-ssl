local shell_blocking = require "shell-games"

local _M = {}

local function file_path(self, key)
  return self.options["dir"] .. "/storage/file/" .. ngx.escape_uri(key)
end

function _M.new(uiza_ssl_instance)
  local options = {
    dir = uiza_ssl_instance:get("dir")
  }

  return setmetatable({ options = options }, { __index = _M })
end

function _M.get(self, key)
  local file, err = io.open(file_path(self, key), "r")
  if err and string.find(err, "No such file") then
    return nil
  elseif err then
    return nil, err
  end

  local content = file:read("*all")
  file:close()
  return content
end

function _M.set(self, key, value, options)
  local file, err = io.open(file_path(self, key), "w")
  if err then
    ngx.log(ngx.ERR, "uiza-ssl: failed to open file for writing: ", err)
    return false, err
  end

  file:write(value)
  file:close()

  if options and options["exptime"] then
    ngx.timer.at(options["exptime"], function()
      local _, delete_err = _M.delete(self, key)
      if delete_err then
        ngx.log(ngx.ERR, "uiza-ssl: failed to remove file after exptime: ", delete_err)
      end
    end)
  end

  return true
end

function _M.delete(self, key)
  local ok, err = os.remove(file_path(self, key))
  if err and string.find(err, "No such file") then
    return false, nil
  elseif err then
    return false, err
  else
    return ok, err
  end
end

function _M.keys_with_suffix(self, suffix)
  local base_dir = self.options["dir"]
  local result, err = shell_blocking.capture_combined({ "find", base_dir .. "/storage/file", "-name", "*" .. ngx.escape_uri(suffix) })
  if err then
    return nil, err
  end

  local keys = {}
  for path in string.gmatch(result["output"], "[^\r\n]+") do
    local filename = ngx.re.sub(path, ".*/", "", "jo")
    local key = ngx.unescape_uri(filename)
    table.insert(keys, key)
  end

  return keys
end

return _M
