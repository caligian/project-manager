local class = require 'lua-utils.class'
local list = require 'lua-utils.list'
local copy = require 'lua-utils.copy'
local dict = require 'lua-utils.dict'
local path = require 'lua-utils.path_utils'
local process = require 'lua-utils.process'
local Fzf = require 'project-manager.fzf'
local Project = require 'project-manager.project'
local utils = require 'project-manager.utils'
local home = os.getenv('HOME')

---@class GlobalProjectConfig
local Config = class 'GlobalProjectConfig'

function Config:initialize()
  self.projects = {}
  self._projects = {}
  self.selector = { cmd = 'fuzzel', args = '' }
  self.write_on_append = true
  self.path = path(home, '.projects.json')
  self.editor = 'nvim'
  self.terminal = 'kitty'
  self.file_browser = 'nautilus'
  self:read()
end

---@param ... Project
function Config:add_project(...)
  list.each({ ... }, function(project)
    self._projects[project.name] = project
    self.projects[project.name] = {
      name = project.name,
      desc = project.description,
      description = project.description,
      path = project.path,
      config_path = project.config_path
    }
  end)
end

function Config:add(directory, description, opts)
  opts = opts or {
    touch = { 'README.md', 'LICENSE' },
    mkdir = {},
    write_on_append = self.write_on_append
  }
  local touch = opts.touch
  local mkdir = opts.mkdir
  local write_on_append = opts.write_on_append

  if not path.is_dir(directory) then
    utils.mkdir(directory)
  end

  if not path.is_git_dir(directory) then
    printf('Initializing git in directory')
    utils.git_init(directory)
  end

  if touch then
    utils.touch(unpack(touch))
  end

  if mkdir then
    utils.mkdir(unpack(mkdir))
  end

  local proj = Project(directory, description, self:as_dict())
  self:add_project(proj)

  if write_on_append then
    self:write()
  end

  return proj
end

function Config:write()
  utils.write_table({
    projects = self.projects,
    file_browser = self.file_browser,
    editor = self.editor,
    terminal = self.terminal,
    selector = self.selector,
    write_on_append = self.write_on_append,
  }, self.path)
end

function Config:list(opts)
  if dict.size(self.projects) == 0 then
    return
  end

  opts = opts or {}
  local name_only = opts.name_only
  local path_only = opts.path_only
  local realpath = opts.realpath
  local short = opts.short
  local names = list.sort(dict.keys(self.projects))
  local print_proj = function(name, nl)
    local proj = self.projects[name]

    if not short then
      printf('`%s`', proj.name)
      printf('Directory: %s', proj.path)

      if proj.description then
        printf('Description: %s', proj.description)
      end

      if nl then
        print()
      end
    elseif name_only then
      print(proj.name)
    elseif path_only then
      if realpath then
        print(proj.path)
      else
        print((utils.home2tilde(proj.path)))
      end
    elseif realpath then
      print(proj.path)
    else
      print((utils.home2tilde(proj.path)))
    end
  end

  for i = 1, #names - 1 do
    print_proj(names[i], true)
  end

  print_proj(names[#names], false)
end

function Config:select(fzf_opts, callback)
  local cmd = self.selector.cmd
  local args = self.selector.args
  local fzf = Fzf(cmd)
  local projs = list.sort(dict.keys(self.projects))

  if #projs == 0 then
    print('No projects to select')
    os.exit(1)
  end


  fzf:set(list.map(projs, function(name)
    ---@diagnostic disable-next-line
    return { name, self.projects[name].description or '<No description>' }
  end))

  local choice = fzf:run(fzf_opts or args)
  if not choice then
    print('No project selected')
    os.exit(1)
  end

  callback(self._projects[choice[1]])
end

function Config:fzf_open_terminal(fzf_opts, opts)
  self:select(fzf_opts, function(proj)
    proj:open_terminal(opts)
  end)
end

function Config:fzf_start_tmux(fzf_opts, opts)
  self:select(fzf_opts, function(proj)
    opts = copy(opts or {})
    opts.tmux = true
    proj:open_terminal(opts)
  end)
end

function Config:fzf_open_editor(fzf_opts)
  self:select(fzf_opts, function (proj)
    proj:open_editor()
  end)
end

function Config:fzf_file_browser(fzf_opts)
  self:select(fzf_opts, function (proj)
    proj:open_file_browser()
  end)
end

function Config:discover(start_dir, opts)
  opts = opts or {}
  local depth = opts.depth or 5
  local add = opts.add
  local exclude = opts.exclude
  local realpath = opts.realpath
  local include = opts.include

  local function find(dirname, result, current_depth)
    if current_depth == depth then
      return result
    end

    result = result or {}
    local dirs = path.ls_dir(dirname)
    local git_dirs = list.filter(dirs, path.is_git_dir)

    for i = 1, #git_dirs do
      git_dirs[git_dirs[i]] = true
      result[#result + 1] = git_dirs[i]
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
    local use = true
    use = include and (dir:match(include) ~= nil) or use
    use = exclude and (not dir:match(exclude)) or use
    local display = realpath and (dir:gsub(home, "~")) or dir

    if use then
      if not realpath then
        print(display)
      else
        print(dir)
      end

      if add then
        self:add(dir, false, { write_on_append = false })
      end
    end
  end

  if add then
    self:write()
  end

  return results
end

function Config:as_dict()
  return {
    editor = self.editor,
    terminal = self.terminal,
    file_browser = self.file_browser,
    selector = self.selector,
    write_on_append = self.write_on_append,
    projects = self.projects
  }
end

function Config:read()
  if path.is_file(self.path) then
    local config = utils.read_table(self.path, {})
    dict.force_merge(self, config)
  end

  for name, spec in pairs(self.projects) do
    self._projects[name] = Project(
      spec.path, spec.desc, self:as_dict()
    )
  end
end

-- local config = Config()
-- config:read()
--
-- config:add(
--   '/home/caligian/Repos/nvim-utils',
--   'My neovim Configuration'
-- )
--
-- config:add(
--   '/home/caligian/Repos/lua-utils',
--   'Indispensable lua utilities'
-- )
--
-- config:add(
--   '/home/caligian/Scripts/deepseek',
--   'Python Deepseek client'
-- )
--
-- config:discover('/home/caligian/Scripts', {add = true})
--
-- config:terminal()

return Config
