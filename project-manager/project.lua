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
    local confirm = io.read("*l")
    if confirm:match 'y' then
      process.run(sprintf('cd %s && git init', self.path))
    end
  end
end

function Project:cd(f)
  if f then
    local currentdir = path.getcwd()
    path.cd(self.path)
    local res = {f()}
    path.cd(currentdir)

    return unpack(res)
  else
    path.cd(self.path)
  end
end

function Project:exec(cmd, f)
  self:cd(function ()
    printf(
      '%-30s: %s',
      utils.home2tilde(self.path), cmd
    )
    process.check_output(cmd, function (out)
      if #out == 0 then return end
      if f then f(out) end
    end)
  end)
end

function Project:find_files()
  self:exec('git ls-files', function (out)
    self.files = string.split(out, "\n")
    self.files = list.map(self.files, string.trim)
    self.files = list.map(self.files, path.abspath)
  end)
end

function Project:ripgrep(arguments)
  arguments = arguments or ''
  arguments = arguments .. ' --vimgrep'
  local cmd = sprintf(
    'rg %s %s', arguments,
    table.concat(self.files, ' ')
  )
  self:exec(cmd, print)
end

Project.rg = Project.ripgrep

function Project:grep(arguments)
  arguments = arguments or ''
  arguments = arguments .. ' -Piln'
  local cmd = sprintf(
    'grep %s %s', arguments,
    table.concat(self.files, ' ')
  )
  self:exec(cmd, print)
end

function Project:open_terminal(opts)
  opts = opts or {}
  local terminal = opts.terminal or self.config.terminal or 'kitty'
  local tmux = opts.tmux
  local cmd = ''

  if tmux then
    cmd = sprintf('%s -e tmux', terminal)
  else
    cmd = terminal
  end

  self:exec(cmd)
end

function Project:start_tmux(terminal)
  self:open_terminal {
    tmux = true,
    terminal = terminal
  }
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
  self:exec(cmd, print)
end

function Project:open_file_browser(file_browser)
  file_browser = file_browser or self.config.file_browser or 'nautilus'
  local cmd = file_browser .. ' ' .. self.path
  self:exec(cmd)
end

function Project:open_editor(opts)
  opts = opts or {}
  local terminal = opts.terminal or self.config.terminal or 'kitty'
  local editor = opts.editor or self.config.editor or 'nvim'
  self:exec(sprintf('%s -e %s', terminal, editor))
end

return Project
