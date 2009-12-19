module Laminate
  class State < Rufus::Lua::State
    STANDARD_LUA_LIBS = [:base, :string, :math, :table]

    @@enable_timeouts = false
    # Enable or disable Lua timeouts. You shouldn't call this function directly, but rather use: require 'laminate/timeouts'. That
    # helper includes all the required timeout components and enables this setting.
    def self.enable_timeouts=(val)
      @@enable_timeouts = val
    end

    def self.enable_timeouts
      @@enable_timeouts
    end

    def initialize(options = {})
      super STANDARD_LUA_LIBS
      Rufus::Lua::State.debug = true if ENV['LUA_DEBUG']
      @wrap_exceptions = !options[:wrap_exceptions].nil? ? options[:wrap_exceptions] : true
      @timeout = (options[:timeout] || 15).to_i
      @helper_methods = []
      sandbox_lua
    end

    def setup_alarm
      if @@enable_timeouts
        eval("alarm(#{@timeout}, function() error('template timeout'); end)")
        eval("alarm = function(arg, arg) end")
      end
    end

    def clear_alarm
      if @@enable_timeouts
        Rufus::Lua::Lib._clear_alarm
      end
    end

    def sandbox_lua
      # Should include string.find ...
      [:loadfile, :collectgarbage, :_G, :getfenv, :getmetatable, :setfenv, :setmetatable, 'string.rep'].each do |badfunc|
        eval("#{badfunc} = nil")
      end
      eval("function string.rep(count) return 'rep not supported'; end")
      if @@enable_timeouts
        init_lua_alarm
      end
    end

  end
end