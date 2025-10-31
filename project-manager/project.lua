require 'lua-utils.utils'
local class = require 'lua-utils.class'
local list = require 'lua-utils.list'
local dict = require 'lua-utils.dict'
local path = require 'lua-utils.path_utils'
local process = require 'lua-utils.process'
local Fzf = require 'project-manager.fzf'
local utils = require 'project-manager.utils'

---@class Selector
---@field cmd string
---@field args string

---@class ProjectConfig
---@field selector? Selector
---@field editor? string
---@field write_on_append? boolean
---@field terminal? string
---@field file_browser? string

---@class Project
---@field description string
---@field desc string
---@field name string
---@field path string
---@field dir string
---@field directory string
---@field dirname string
---@field files string[]
---@field config_path string
---@field config ProjectConfig
---@field fzf Fzf
---@overload fun(directory: string, description: string, opts?: ProjectConfig)
local Project = class 'Project'

function Project:initialize(
  directory,
  description,
  opts
)
  opts = opts or {}
  self.description = description or false
  self.desc = self.description
  self.name = path.basename(directory)
  self.path = directory
  self.dirname = directory
  self.directory = directory
  self.dir = directory
  self.files = {}
  self.config_path = path(self.path, '.project.json')
  self.config = utils.read_table(self.config_path)
  self.config = self.config or opts or {selector = {cmd = 'fuzzel', args = ''}}
  self.fzf = Fzf(self.config.selector.cmd)

  if not path.is_git_dir(self.path) then
    printf('%s is not a git directory. Initializing git...', self.path)
    process.run(sprintf('cd %s && git init', self.path))
  end

  -- self:find_files()
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
  local terminal = opts.terminal or self.config.terminal or 'kitty'
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

function Project:start_tmux()
  
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
  process.check_output(cmd, utils.print)
end

function Project:open_file_browser(file_browser)
  file_browser = file_browser or self.config.file_browser or 'nautilus'
  local cmd = file_browser .. ' ' .. self.path
  process.run(cmd)
end

function Project:shell_command(cmd)
  local currentdir = path.getcwd()
  path.cd(self.path)
  process.check_output(cmd, utils.print)
  path.cd(currentdir)
end

function Project:open_editor(opts)
  opts = opts or {}
  local terminal = opts.terminal or self.config.terminal or 'kitty'
  local editor = opts.editor or self.config.editor or 'nvim'
  local currentdir = path.getcwd()
  path.cd(self.path)
  process.run(sprintf('%s -e %s', terminal, editor))
  path.cd(currentdir)
end

return Project
