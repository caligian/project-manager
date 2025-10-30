package = "project-manager"
version = "dev-1"

source = {
  url = "git+https://github.com/caligian/project-manager.git",
}

description = {
  homepage = "https://github.com/caligian/project-manager",
  license = "MIT <http://opensource.org/licenses/MIT>",
}

dependencies = { "lua >= 5.1", "lua-utils", 'luasystem' }

build = {
  type = "builtin",
  modules = {
    ["project-manager"] = "project-manager/init.lua",
    ['project-manager.cmdline'] = 'project-manager/cmdline.lua',
    ['project-manager.config'] = 'project-manager/config.lua',
    ['project-manager.utils'] = 'project-manager/utils.lua',
    ['project-manager.project'] = 'project-manager/project.lua',
    ['project-manager.fzf'] = 'project-manager/fzf.lua',
  },
}
