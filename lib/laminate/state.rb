module Laminate
  class State < Rufus::Lua::State
    STANDARD_LUA_LIBS = [:base, :string, :math, :table]
    BUILTIN_FUNTIONS = File.open(File.expand_path(File.dirname(__FILE__) + '/lua_functions/builtin.lua')).readlines.join("\n")

    attr_reader :timeout

    @@enable_timeouts = false
    # Enable or disable Lua timeouts. You shouldn't call this function directly, but rather use: require 'laminate/timeouts'. That
    # helper includes all the required timeout components and enables this setting.
    def self.enable_timeouts=(val)
      @@enable_timeouts = val
    end

    def self.enable_timeouts
      @@enable_timeouts
    end

    # Is passed the options from Template#render
    #   :locals -> A hash of variables to make available to the template (simply types, Hashes, and Arrays only. Nesting OK)
    #   :helpers -> An array of Modules or instances to make available as functions to the template.
    #   :raise_errors -> (true|false) If true, then errors raise an exception. Otherwise an error message is printed as the template result.
    #   :wrap_exceptions => (*true|false) If true, then Ruby exceptions are re-raised in Lua. This incurs a small performance penalty.
    #   :timeout -> Max run time in seconds for the template. Default is 15 secs.
    def initialize(options = {})
      super STANDARD_LUA_LIBS
      Rufus::Lua::State.debug = true if ENV['LUA_DEBUG']
      @wrap_exceptions = !options[:wrap_exceptions].nil? ? options[:wrap_exceptions] : true
      @timeout = (options[:timeout] || 15).to_i
      @helper_methods = []
      @options = options
      sandbox_lua
    end

    # This block runs the state and handles errors
    # It closes the state at the end
    def run(template, lua)
      begin
        self.eval(lua)
        self.setup_builtin_funcs(template)
        self.load_locals(@options[:locals])
        view = LuaView.new
        self.load_helpers(@options[:helpers], template, view)
        self.setup_alarm
        yield self
      rescue Rufus::Lua::LuaError => err
        wrapper = template.render_error err, lua
        if @options[:raise_errors]
          raise wrapper
        else
          template.errors << wrapper
          return wrapper.to_html
        end
      ensure
        # currently we aren't keeping around the Lua state between renders
        self.clear_alarm
        self.close
        #puts "<< END LAMINATE RENDER. Enabling gc."
        #GC.enable
      end
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

    def load_helpers(helpers, template, view)
      (helpers || []).each do |helper|
        if helper.is_a?(Module)
          LuaView.send(:include, helper)
          template.bind_lua_funcs(view, helper.public_instance_methods(false), helper, self, view)
          nil
        else
          template.bind_lua_funcs(helper, helper.class.public_instance_methods(false), helper.class, self, view)
          nil
        end
      end
      return
    end


    def load_locals(locals_hash)
      unless locals_hash.nil?
        stringify_keys!(locals_hash)
        self.function '_getlocal' do |name|
          locals_hash[name]
        end
        locals_hash.keys.each {|key| self.eval("#{key} = _getlocal('#{key}')")}
        # Record locals for debug_info function
        @local_data = locals_hash.keys.collect {|k| k.to_s}
      end
      return
    end

    def setup_builtin_funcs(template)
      self.function 'debug_all' do
        "<pre>Functions:\n  " +
        template.helper_methods.join("\n  ") +
        "\nData:\n" +
        @local_data.collect do |local|
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

    protected

    # Recursively converts symbol keys to string keys in a hash
    def stringify_keys!(hash)
      if hash.is_a?(Hash)
        hash.keys.each do |key|
          hash[key.to_s] = stringify_keys!(hash.delete(key))
        end
        hash
      elsif hash.is_a?(Array)
        hash.collect {|elt| stringify_keys!(elt)}
      else
        hash
      end
    end
  end
end