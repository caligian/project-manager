require 'lua-utils.utils'
require 'lua-utils.string'
local process = require 'lua-utils.process'
local path = require 'lua-utils.path_utils'
local utils = { HOME = os.getenv("HOME") }
local json = require 'json'

function utils.print(out)
  out = out:trim()
  if #out > 0 then print(out) end
end

function utils.git_init(directory)
  process.run(sprintf('cd %s && git init', directory))
end

function utils.git(directory, cmd)
  process.run(sprintf('cd %s && git %s', directory, cmd))
end

function utils.read_table(filename, defaults)
  if not path.is_file(filename) then
    return defaults
  end

  local ok, msg = pcall(json.decode, slurp(filename))
  if ok then
    return msg
  else
    printf('Error loading configuration from filename: %s', msg)
    return defaults
  end
end

function utils.write_table(t, filename)
  spit(json.encode(t), filename)
end

function utils.home2tilde(s)
  return s:gsub(utils.HOME, "~")
end

function utils.tilde2home(s)
  return s:gsub('~', utils.HOME)
end

return utils
