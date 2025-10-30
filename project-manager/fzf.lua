#!/usr/bin/luajit

require 'lua-utils.utils'
require 'lua-utils.string'

local path = require 'lua-utils.path_utils'
local list = require 'lua-utils.list'
local process = require 'lua-utils.process'
local class = require 'lua-utils.class'

---Create a fuzzy finder runner
---@class Runner
---@field name string 
---@overload fun(name: string)
local Runner = class 'Runner'

function Runner:initialize(name, arguments)
  self.name = name
  self.arguments = arguments or ''

  if self.name == 'dmenu' then
    self.path = '/usr/bin/' .. name .. '_run'
  else
    self.path = '/usr/bin/' .. name
  end

  if not path.is_file(self.path) then
    printf("%s is not installed on your system")
    os.exit(1)
  end
end

---Create command to run and select an option
---@param display string[]
---@param additional_args? string Additional arguments to pass
---@return string
function Runner:make_command(display, additional_args)
  if self.name == 'fzf' then
    return additional_args or self.arguments
  end

  additional_args = additional_args or ''
  local name = self.name
  local final = {self.path}
  local maxwidth = math.max(unpack(list.map(
    ---@diagnostic disable-next-line
    display, function (line) return #line end
  )))
  maxwidth = maxwidth + 2
  maxwidth = ifelse(maxwidth < 15, 15, maxwidth)
  local nlines = #display
  local add_arg = function (...)
    list.append(final, ...)
  end

  if name == 'wofi' or name == 'fuzzel' then
    add_arg('--lines', nlines)
    add_arg('--width', maxwidth)
    add_arg('--dmenu')
    if name == 'fuzzel' and not additional_args:match('font') then
      add_arg('--font', '"Liberation Mono:size=15"')
    end
  elseif name == 'rofi' then
    add_arg('-l', nlines)
    add_arg('-dmenu')
    if not string.match(additional_args, 'font') then
      add_arg('-font', '"Liberation Mono 15"')
    end
  end

  final[#final+1] = self.arguments
  final[#final+1] = additional_args

  return string.trim(table.concat(final, " "))
end

---Run command and get the selected option
---@param lines string[]
---@param additional_args? string Additional arguments to pass
---@return string?
function Runner:run(lines, additional_args)
  local cmd = sprintf(
    'echo -e "%s" | %s',
    table.concat(lines, "\n"),
    self:make_command(lines, additional_args or '')
  )
  local choice = process.check_output(cmd):trim()
  if #choice == 0 then
    return
  else
    return choice
  end
end

---@class FzfOption
---@field [1] string
---@field [2] string

---Create a generic fuzzy finder object
---@class Fzf
---@field options table<string,FzfOption> Options with their descriptions keyed by option
---@field display table<string,string> Contains all the lines to be displayed
---@field valid_runners string[] Valid runners (should be any of fzf, wofi, rofi, dmenu, fuzzel)
---@field runner Runner
---@overload fun(runner: string)
local Fzf = class 'Fzf'

function Fzf:initialize(runner)
  self.options = {}
  self.display = {}
  self.valid_runners = {
    fzf = true,
    wofi = true,
    fuzzel = true,
    rofi = true,
    dmenu = true,
    'fzf', 'wofi', 'fuzzel', 'rofi', 'dmenu'
  }

  runner = runner or 'fzf'
  if not self.valid_runners[runner] then
    print('Runner should be any of wofi, rofi, fuzzel, dmenu, fzf')
    os.exit(1)
  end

  self.runner = Runner(runner)
end

function Fzf:run(additional_args)
  local choice = self.runner:run(self.display, additional_args)
  if choice then
    return self.options[self.display[choice]]
  end
end

---@param options FzfOption[]
function Fzf:set(options)
  local opts = list.map(options, function (opt)
    return opt.option or opt[1]
  end)
  local descs = list.map(options, function (opt)
    return opt.description or opt.desc or opt[2]
  end)
  local max_opt_len = math.max(
    unpack(list.map(opts, function (o)
      ---@diagnostic disable-next-line
      return #o
    end))
  )

  for i =1, #opts do
    local o = opts[i]
    local d = descs[i]
    local whitespace = string.rep(' ', max_opt_len - #o)
    local display = o .. whitespace .. ' :: ' .. d
    self.display[display] = o
    self.display[#self.display+1] = display
    self.options[o] = {o, d}
  end
end

function Fzf:reset()
  self.display = {}
  self.options = {}
end

return Fzf
