package = "lua-utils"
version = "dev-1"

source = {
  url = "git+https://github.com/caligian/lua-utils.git",
}

description = {
  homepage = "https://github.com/caligian/lua-utils",
  license = "MIT <http://opensource.org/licenses/MIT>",
}

dependencies = { "lua >= 5.1", "lpath", 'luv', 'luasystem' }

build = {
  type = "builtin",
  modules = {
    ["lua-utils"] = "lua-utils/init.lua",
    ['lua-utils.utils'] = 'lua-utils/utils.lua',
    ['lua-utils.validate'] = 'lua-utils/validate.lua',
    ['lua-utils.list'] = 'lua-utils/list.lua',
    ['lua-utils.types'] = 'lua-utils/types.lua',
    ['lua-utils.dict'] = 'lua-utils/dict.lua',
    ['lua-utils.string'] = 'lua-utils/string.lua',
    ['lua-utils.multimethod'] = 'lua-utils/multimethod.lua',
    ['lua-utils.copy'] = 'lua-utils/copy.lua',
    ['lua-utils.template'] = 'lua-utils/template.lua',
    ['lua-utils.argparser'] = 'lua-utils/argparser.lua',
    ['lua-utils.exception'] = 'lua-utils/exception.lua',
    ['lua-utils.inspect'] = 'lua-utils/inspect.lua',
    ['lua-utils.class'] = 'lua-utils/class.lua',
    ['lua-utils.cmp'] = 'lua-utils/cmp.lua',
    ['lua-utils.tuple'] = 'lua-utils/tuple.lua',
    ['lua-utils.path_utils'] = 'lua-utils/path_utils.lua',
    ['lua-utils.process'] = 'lua-utils/process.lua',
  },
}
