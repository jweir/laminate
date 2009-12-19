module Laminate
  class State < Rufus::Lua::State
    STANDARD_LUA_LIBS = [:base, :string, :math, :table]
    BUILTIN_FUNTIONS = File.open(File.expand_path(File.dirname(__FILE__) + '/lua_functions/builtin.lua')).readlines.join("\n")

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

    def setup_builtin_funcs(template)
      self.function 'debug_all' do
        "<pre>Functions:\n  " +
        template.helper_methods.join("\n  ") +
        "\nData:\n" +
        template.local_data.collect do |local|
          val = self[local]
          val = val.is_a?(String) ? val : (val.respond_to?(:to_h) ? val.to_h.inspect : val.to_s)
          "  #{local} = #{val}"
        end.join("\n") + "</pre>"
      end

      self.eval BUILTIN_FUNTIONS

      # Included template functions. The trick is that we don't return to Ruby and eval the included template, because the
      # Lua binding doesn't like re-entering eval. So instead we bind a function '_load_template' which returns the template
      # code, and then we eval it inside Lua itself using 'loadstring'. Thus the template 'include' function is actually
      # a native Lua function.
      self.function '_load_template' do |name|
        template.prepare_template(name)
        template.load_template_innerds(name)
      end
    end

  end
end