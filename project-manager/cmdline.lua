local dict = require 'lua-utils.dict'
local path = require 'lua-utils.path_utils'
local Argparser = require 'lua-utils.argparser'
local Config = require 'project-manager.config'
local utils = require 'project-manager.utils'

---Commandline module
local cmdline = {}
local print_and_exit = Argparser.utils.print_and_exit

function cmdline.parse_args(args)
  ---@type Argparser
  local parser = Argparser("Project management utilities in lua")

  --- Add new projects with marker files and directories
  parser:K('a', 'add', {
    nargs = 1,
    help = 'Add a project directory'
  })
  parser:K('n', 'name', {
    nargs = '?',
    help = 'Use this name instead of directory basename'
  })
  parser:K('d', 'description', {
    nargs = 1,
    help = 'Some description for the project'
  })
  parser:K(nil, 'touch', {
    nargs = '+',
    help = 'Create empty files in project root'
  })
  parser:K(nil, 'mkdir', {
    duplicate = true,
    nargs = '+',
    help = 'Create empty directories in project root'
  })

  --- Project discovery
  parser:K('o', 'discover', {
    help = 'Find projects in directory (or current directory). Can be used with --depth',
    metavar = 'DIRECTORY',
    nargs = '?'
  })
  parser:K('O', 'discover-and-add', {
    help = 'Find projects in directory (or current directory) and add them. Can be used with --depth',
    metavar = 'DIRECTORY',
    nargs = '?'
  })
  parser:K(nil, 'depth', {
    help = 'To be used with --discover. Depth to traverse to for discovering projects (default: 3)',
    metavar = 'DEPTH',
    post = tonumber,
    assert = function(value)
      local ok = string.match(value, '^[0-9]+$')
      if not ok then
        return false, sprintf('Expected number, got %s', value)
      else
        return true
      end
    end,
    nargs = '?'
  })

  --- List projects
  parser:K('l', 'list', {
    help = 'List recorded project directories. Can be used with --name-only OR --path-only'
  })
  parser:K(nil, 'name-only', {
    help = 'To be used with --list. Print only the name of the recorded projects'
  })
  parser:K(nil, 'path-only', {
    help = 'To be used with --list. Print only the paths of the recorded projects'
  })
  parser:K(nil, 'realpath', {
    help = 'To be used with --list. Print full paths'
  })

  --- Fzf stuff
  parser:K('s', 'selector', {
    help = '(default: fuzzel) Use this selector.'
  })
  parser:K('S', 'selector-args', {
    help = '(default: "") Use these additional arguments'
  })
  parser:K('t', 'terminal', {
    nargs = '?',
    metavar = 'TERMINAL-APPLICATION',
    help = 'Select project and open terminal in project root'
  })
  parser:K('T', 'tmux', {
    nargs = '?',
    metavar = 'TERMINAL-APPLICATION',
    help = "Select project, open terminal and start tmux in project root"
  })
  parser:K('f', 'file-browser', {
    help = 'Select project and open file browser'
  })
  parser:K('e', 'editor', {
    help = 'Select project and open project root in that editor'
  })

  local parsed = parser:parse(args or arg)
  return parser, parsed
end

---@type Argparser
local parser, parsed = cmdline.parse_args(arg)
---@type GlobalProjectConfig
local config = Config()
local kw = parsed.keyword_arguments

if dict.size(parsed.keyword_arguments) == 0 then
  print(parser:create_inline_help())
  print('\nNo arguments provided')
  os.exit(1)
end

if kw.discover or kw.discover_and_add then
  local dir
  local add = kw.discover_and_add ~= nil

  if kw.discover then
    dir = kw.discover[1]
  elseif add then
    dir = kw.discover_and_add[1]
  end

  dir = utils.tilde2home(dir)
  dir = dir or path.getcwd()
  utils.assert_dir(dir)

  config:discover(dir, {
    depth = kw.depth,
    add = add
  })
elseif kw.add then
  local dir = utils.tilde2home(kw.add[1])
  utils.assert_dir(dir)
  config:add(dir, kw.description[1], {
    write_on_append = true,
    name = kw.name and kw.name[1]
  })
elseif kw.list then
  config:list {
    short = (kw.name_only or kw.path_only) and true or false,
    name_only = kw.name_only and true,
    path_only = kw.path_only and true,
    realpath = kw.realpath and true
  }
elseif kw.tmux then
  config:fzf_open_terminal(kw.selector_args, {
    tmux = true,
    terminal = kw.tmux[1]
  })
elseif kw.terminal then
  config:fzf_open_terminal(kw.selector_args, {
    terminal = kw.terminal[1]
  })
elseif kw.editor then
  config:fzf_open_editor(kw.selector_args)
elseif kw.file_browser then
  config:fzf_file_browser(kw.selector_args)
else
  parser:print_help_and_exit()
  print()
  print('Invalid arguments provided')
end

return cmdline
