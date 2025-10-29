require 'lua-utils.utils'
local class = require 'lua-utils.class'
local list = require 'lua-utils.list'
local copy = require 'lua-utils.copy'
local dict = require 'lua-utils.dict'
local path = require 'lua-utils.path_utils'
local process = require 'lua-utils.process'
local Fzf = require 'project-manager.fzf'
local utils = require 'project-manager.utils'
local home = os.getenv('HOME')

---@class Project
local Project = class 'Project'

function Project:initialize(directory, description)
  self.description = description or false
  self.desc = self.description
  self.name = path.basename(directory)
  self.path = directory
  self.files = {}
  self.config_path = path(self.path, '.project.json')
  self.config = utils.read_table(self.config_path, {
    selector = {cmd = 'fuzzel', args = ''}
  })
  self.fzf = Fzf(self.config.selector.cmd)

  if not path.is_git_dir(self.path) then
    printf('%s is not a git directory. Initializing git...', self.path)
    process.run(sprintf('cd %s && git init', self.path))
  end
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

function Project:terminal(opts)
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
  process.check_output(cmd, utils.print)
end

function Project:file_browser(file_browser)
  file_browser = file_browser or 'nautilus'
  local cmd = file_browser .. ' ' .. self.path
  process.run(cmd)
end

function Project:shell_command(cmd)
  local currentdir = path.getcwd()
  path.cd(self.path)
  process.check_output(cmd, utils.print)
  path.cd(currentdir)
end

return Project
