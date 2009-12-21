# Laminate
def find_lib
  directory = File.expand_path(File.dirname(__FILE__) + '/../lua/')
  ENV['LUA_LIB'] = [Dir.glob("#{directory}/liblua*.*")].flatten.first
end

find_lib

require 'laminate/loader'
require 'laminate/template_error'
require 'laminate/compiler'
require 'laminate/template'
require 'laminate/abstract_lua_helper'
require 'laminate/core_tolua'
require 'laminate/state'

