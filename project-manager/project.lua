require 'lua-utils.utils'
local class = require 'lua-utils.class'
local path = require 'lua-utils.class'
local Project = class 'Project'

function Project:initialize(directory)
  self.path = directory
end
