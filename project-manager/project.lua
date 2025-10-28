require 'lua-utils.utils'
local class = require 'lua-utils.class'
local list = require 'lua-utils.list'
local copy = require 'lua-utils.copy'
local dict = require 'lua-utils.dict'
local path = require 'lua-utils.path_utils'
local process = require 'lua-utils.process'
local Fzf = require 'project-manager.fzf'
local Project = class 'Project'
local home = os.getenv('HOME')
Project.projects = {}
Project.global_config_path = path(home, '.projects.lua')
Project.global_config = {
  selector = { cmd = 'fuzzel', args = '' },
  projects = {},
  write_on_append = true,
}

local function git_init(directory)
  process.run(sprintf('cd %s && git init', directory))
end

local function print_output(out)
  out = out:trim()
  if #out > 0 then
    print(out)
  end
end

local function load_table(filename, defaults)
  defaults = defaults or { selector = { cmd = 'fuzzel', args = '' } }

  if path.is_file(filename) then
    local text = slurp(filename)
    text = 'return {' .. text .. '}'
    local chunk = loadstring(text)
    local ok, msg = chunk()

    if not ok then
      printf('Error loading project configuration: %s\nReturning defaults', msg)
      return defaults
    else
      return ok
    end
  else
    return defaults
  end
end

function Project:initialize(directory, description)
  directory = path.abspath(directory)
  self.description = description or false
  self.name = path.basename(directory)
  self.path = directory
  self.files = {}
  self.config_path = path(self.path, '.project.lua')
  self.config = load_table(self.config_path)
  self.fzf = Fzf(self.config.selector.cmd)

  if not path.is_git_dir(self.path) then
    printf('%s is not a git directory. Initializing git...', self.path)
    process.run(sprintf('cd %s && git init', self.path))
  end

  Project.projects[self.name] = self
  Project.global_config.projects[self.name] = {
    path = self.path,
    description = self.description
  }
end

function Project:find_files()
  process.check_output('git ls-files', function(out)
    out = out:trim()
    self.files = string.split(out, "\n")
    self.files = list.map(self.files, string.trim)
  end)
end

function Project:ripgrep(arguments)
  arguments = arguments or ''
  arguments = arguments .. ' --vimgrep'
  local cmd = sprintf(
    'rg %s %s', arguments,
    table.concat(self.files, ' ')
  )
  process.check_output(cmd, function(out)
    print(out)
  end)
end

Project.rg = Project.ripgrep

function Project:grep(arguments)
  arguments = arguments or ''
  arguments = arguments .. ' -Pil'
  local cmd = sprintf(
    'grep %s %s', arguments,
    table.concat(self.files, ' ')
  )
  process.check_output(cmd, function(out)
    print(out)
  end)
end

function Project:open_terminal(opts)
  opts = opts or {}
  local terminal = opts.terminal or 'kitty'
  local tmux = opts.tmux
  local cmd = ''
  local currentdir = path.getcwd()

  if tmux then
    cmd = sprintf('%s -e tmux', terminal)
  else
    cmd = terminal
  end

  path.cd(self.path)
  process.run(cmd)
  path.cd(currentdir)
end

function Project:sed(pattern, sub, all)
  local cmd = sprintf('sed -ri "s/%s/%s/"', pattern, sub)
  if all then cmd = cmd .. 'g' end
  local files = list.filter(self.files, path.is_file)

  if #files == 0 then
    print('No files to replace in project root')
    os.exit(1)
  end

  files = table.concat(files, " ")
  cmd = cmd .. ' ' .. files
  process.check_output(cmd, print_output)
end

function Project:file_browser(file_browser)
  file_browser = file_browser or 'nautilus'
  local cmd = file_browser .. ' ' .. self.path
  process.run(cmd)
end

function Project:shell_command(cmd)
  local currentdir = path.getcwd()
  path.cd(self.path)
  process.check_output(cmd, print_output)
  path.cd(currentdir)
end

function Project.read_global_config()
  if path.is_file(Project.global_config_path) then
    local config = load_table(
      Project.global_config_path,
      Project.global_config
    )
    Project.global_config = config
  end

  Project.global_config.projects = Project.global_config.projects or {}
  Project.global_config.selector = Project.global_config.selector or {
    cmd = 'fuzzel', args = ''
  }
end

function Project.add_directory(directory, description, create)
  create = create or {
    touch = { 'README.md', 'LICENSE' },
    mkdir = {},
    write_on_append = Project.global_config.write_on_append
  }

  directory = path.abspath(directory)
  if not path.is_dir(directory) then
    path.fs.mkdir(directory)
  end

  if not path.is_git_dir(directory) then
    git_init(directory)
  end

  if create.touch then
    for i = 1, #create.touch do
      process.run('touch ' .. create.touch[i])
    end
  end

  if create.mkdir then
    for i = 1, #create.mkdir do
      process.run('mkdir ' .. path(directory, create.mkdir[i]))
    end
  end

  local proj =  Project(directory, description)
  if create.write_on_append then
    Project.write_global_config()
  end
end

function Project.write_global_config()
  spit(
    inspect(Project.global_config),
    Project.global_config_path
  )
end

function Project.list_projects()
  local home = os.getenv("HOME")
  local names = list.sort(dict.keys(Project.projects))
  local print_proj = function(name, nl)
    local proj = Project.projects[name]
    printf('`%s`', proj.name)
    printf('Directory: %s', proj.path)

    if proj.description then
      printf('Description: %s', proj.description)
    end

    if nl then
      print()
    end
  end

  for i=1, #names - 1 do
    print_proj(names[i], true)
  end

  print_proj(names[#names], false)
end

Project.add_dir = Project.add_directory

function Project.fzf_select_project(fzf_opts, callback)
  local cmd = Project.global_config.selector.cmd
  local args =  Project.global_config.selector.args
  local fzf = Fzf(cmd)
  local projs = list.sort(dict.keys(Project.projects))

  if #projs == 0 then
    print('No projects to select')
    os.exit(1)
  end


  fzf:set(list.map(projs, function (name)
    ---@diagnostic disable-next-line
    return {name, Project.projects[name].description}
  end))

  local choice = fzf:run(fzf_opts)
  if not choice then
    print('No project selected')
    os.exit(1)
  end

  callback(Project.projects[choice[1]])
end

function Project.fzf_open_terminal(fzf_opts, opts)
  Project.fzf_select_project(fzf_opts, function (proj)
    proj:open_terminal(opts)
  end)
end

function Project.fzf_open_terminal_with_tmux(fzf_opts, opts)
  Project.fzf_select_project(fzf_opts, function (proj)
    opts = copy(opts or {})
    opts.tmux = true
    proj:open_terminal(opts)
  end)
end

function Project.discover(start_dir, depth)
  depth = depth or 5

  local function find(dirname, result, current_depth)
    if current_depth == depth then
      return result
    end

    result = result or {}
    local dirs = path.ls_dir(dirname)
    local git_dirs = list.filter(dirs, path.is_git_dir)

    for i=1, #git_dirs do
      git_dirs[git_dirs[i]] = true
      result[#result+1] = git_dirs[i]
    end

    for i = 1, #dirs do
      if not git_dirs[dirs[i]] then
        find(dirs[i], result, current_depth + 1)
      end
    end
  end

  local results = {}
  find(start_dir, results, 0)

  if #results == 0 then
    printf("No projects found in %s", start_dir)
    os.exit(1)
  end

  for _, dir in ipairs(results) do
    print((dir:gsub(home, "~")))
  end

  return results
end

Project.read_global_config()

Project.add_dir(
  '/home/caligian/Repos/nvim-utils',
  'My neovim configuration'
)

Project.add_dir(
  '/home/caligian/Repos/lua-utils',
  'Indispensable lua utilities'
)

Project.add_dir(
  '/home/caligian/Scripts/deepseek',
  'Python Deepseek client'
)

-- Project.fzf_open_terminal_with_tmux()
Project.discover('/home/caligian/Repos', 2)
