#!/usr/bin/luajit

require 'lua-utils.utils'
local path = require 'lua-utils.path_utils'
local list = require 'lua-utils.list'
local dict = require 'lua-utils.dict'
local class = require 'lua-utils.class'


local projects_file = path(os.getenv("HOME"), '.projects.lua')

local function normalize(s)
  s = s:gsub('/+$', '')
  s = s:gsub('/+', '/')
  return s
end

local function read()
  local projects = slurp(projects_file)
  if not projects then
    return {}
  else
    local chunk = load(projects)
    return chunk()
  end
end

local function print_help()
  print([[Usage: Add/Remove project directories
add <directory> ...
  Add a valid git directory

rm  <directory> ...
  Remove a recorded directory

list
  List all the recorded directories]])
  os.exit(0)
end

local function list_projects(projects)
  if dict.size(projects) == 0 then
    print('No projects have been added yet. Pass `help` to show help')
    os.exit(1)
  end

  for key, _ in pairs(projects) do
    print(key)
  end

  os.exit(0)
end

local function add_projects(projects, ...)
  list.each({...}, function (dirname)
    if dirname == '.' then dirname = path.getcwd() end
    dirname = normalize(dirname)

    if not path.is_dir(dirname) or not path.is_git_dir(dirname) then
      printf("Expected a git repository path, got %s", dirname)
      os.exit(1)
    else
      dirname = path.abspath(dirname)
      projects[dirname] = true
    end
  end)
end

local function rm_projects(projects, ...)
  list.each({...}, function (dirname)
    if dirname == '.' then dirname = path.getcwd() end
    dirname = normalize(dirname)
    dirname = path.abspath(dirname)
    projects[dirname] = nil
  end)
end

local function write(projects)
  local s = inspect(projects)
  s = 'return ' .. s
  spit(s, projects_file)
end

local function main()
  local cmd = arg[1]
  local valid_cmds = {
    list = true,
    rm = true,
    add = true,
    help = true
  }
  local projects = read()

  if not valid_cmds[cmd] then
    cmd = not cmd and 'nothing' or cmd
    printf(
      "Expected argument 1 to be any of %s, got %s",
      table.concat(dict.keys(valid_cmds), ', '),
      cmd
    )
    os.exit(1)
  end

  if cmd == 'help' then
    print_help()
  elseif cmd == 'list' then
    list_projects(projects)
  else
    local files = list.slice(arg, 2, #arg)
    if not files then
      print("No input files defined")
      os.exit(1)
    end

    local f = cmd == 'add' and add_projects or rm_projects
    f(projects, unpack(files))
    write(projects)
    os.exit(0)
  end
end

main()
