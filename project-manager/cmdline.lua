local argparser = require 'lua-utils.argparser'
local config = require 'project-manager.config'

local cmdline = {}

function cmdline.parse_args()
  local parser = argparser(
    "Project management utilities in lua", nil
  )

  parser:K(nil, 'touch', {
    duplicate = true,
    nargs = '+',
  })
  parser:K(nil, 'mkdir', {
    duplicate = true,
    nargs = '+'
  })
  parser:K('l', 'list', {
    nargs = '?',
    assert = function(value)
      return value == 'name' or value == 'realpath'
    end
  })
  parser:K('a', 'add', { nargs = 1 })
  parser:K('d', 'directory', { nargs = 1 })
  parser:K(nil, 'discover', { nargs = 0 })
  parser:K(nil, 'dump', {nargs = 0})

  return parser:parse(arg)
end

pp(cmdline.parse_args())
