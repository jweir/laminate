# Laminate
def find_lib
  directory = File.expand_path(File.dirname(__FILE__) + '/../lua/')
  ENV['LUA_LIB'] = [Dir.glob("#{directory}/liblua**.*")].flatten.first
end

find_lib

begin
  require 'rufus/lua'
rescue Exception => err
  puts "Error, Laminate failed to load because Rufus/Lua failed to load: #{err.message}"
end

require 'laminate/loader'
require 'laminate/parser'
require 'laminate/template_error'
require 'laminate/compiler'
require 'laminate/template'
require 'laminate/abstract_lua_helper'
require 'laminate/core_tolua'
require 'laminate/state'

