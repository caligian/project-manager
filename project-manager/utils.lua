require 'lua-utils.utils'
require 'lua-utils.string'
local dict = require 'lua-utils.dict'
local process = require 'lua-utils.process'
local path = require 'lua-utils.path_utils'
local utils = { HOME = os.getenv("HOME") }
local json = require 'json'

function utils.print_and_exit(s, ...)
  print(s:format(...))
  os.exit(1)
end

function utils.print(out)
  out = out:trim()
  if #out > 0 then print(out) end
end

function utils.mkdir(...)
  local dirs = {...}
  for i=1, #dirs do
    local d = dirs[i]
    local ok, msg = pcall(path.fs.mkdir, d)
    if ok then
      printf('Successfully created directory: %s', d)
    else
      if msg then print(msg) end
      os.exit(1)
    end
  end
end

function utils.touch(...)
  local files = {...}
  for i=1, #files do
    local filename = files[i]
    local ok, msg = pcall(spit, "", filename)
    if ok then
      printf('Successfully created empty file: %s', filename)
    else
      if msg then print(msg) end
      os.exit(1)
    end
  end
end

function utils.git_init(directory)
  process.run(sprintf('cd %s && git init', directory))
end

function utils.git(directory, cmd)
  process.run(sprintf('cd %s && git %s', directory, cmd))
end

function utils.run_with_directory(directory, cmd, ...)
  local currentdir = path.getcwd()
  path.cd(directory)
  process.run(sprintf(cmd, ...))
  path.cd(currentdir)
end

utils.run_with_dir = utils.run_with_directory

function utils.run(cmd, ...)
  process.run(sprintf(cmd, ...))
end

function utils.check_output(cmd, ...)
  process.check_output(sprintf(cmd, ...), utils.print)
end

function utils.check_output_with_directory(directory, cmd, ...)
  local currentdir = path.getcwd()
  path.cd(directory)
  process.check_output(sprintf(cmd, ...), utils.print)
  path.cd(currentdir)
end

utils.check_output_with_dir = utils.check_output_with_directory

function utils.read_table(filename, defaults)
  if not path.is_file(filename) then
    return defaults
  end

  local ok, msg = pcall(json.decode, slurp(filename))
  if ok then
    dict.merge(msg, defaults)
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
  return (s:gsub(utils.HOME, "~"))
end

function utils.tilde2home(s)
  return (s:gsub('~', utils.HOME))
end

function utils.assert_dir(filename)
  if not path.is_dir(filename) then
    utils.print_and_exit('Expected existing directory, got ' .. filename)
  end
  return true
end

function utils.assert_filetype(filename, file_type)
  if not path['is_' .. file_type](filename) then
    utils.print_and_exit('Expected existing %s, got %s', file_type, filename)
  end

  return true
end

return utils
