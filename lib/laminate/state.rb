module Laminate
  # Empty class for lua function binding
  class LuaView; end

  class State < Rufus::Lua::State
    STANDARD_LUA_LIBS = [:base, :string, :math, :table]
    BUILTIN_FUNCTIONS = File.open(File.expand_path(File.dirname(__FILE__) + '/lua_functions/builtin.lua')).readlines.join("\n")
    MAX_ARGUMENTS     = 7 # The maximium number of arguments a function will take
    BLACKLIST         = [ :loadfile,
                          :collectgarbage,
                          :_G,
                          :getfenv,
                          :getmetatable,
                          :setfenv,
                          :setmetatable,
                          'string.rep']

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
    #   :wrap_exceptions => (*true|false) If true, then Ruby exceptions are re-raised in Lua. This incurs a small performance penalty.
    #   :timeout -> Max run time in seconds for the template. Default is 15 secs.
    #   :vendor_lua -> A string of additional Lua functions
    def initialize(options = {})
      super STANDARD_LUA_LIBS
      Rufus::Lua::State.debug = true if ENV['LUA_DEBUG']
      @wrap_exceptions = !options[:wrap_exceptions].nil? ? options[:wrap_exceptions] : true
      @timeout = (options[:timeout] || 15).to_i
      @helper_methods = []
      @options = options
      sandbox_lua
    end

    # This block yeilds the state for eval and function adding
    # It closes the state at the end of the block
    #   error_handler is an optional Proc to be called if a LuaError occurs
    def run(error_handler = nil)
      begin
        setup_builtin_funcs
        load_locals @options[:locals]
        load_helpers @options[:helpers]
        setup_alarm
        yield self
      rescue Rufus::Lua::LuaError => err
        if error_handler.nil?
          raise err
        else
          return error_handler.call(err)
        end
      ensure
        # currently we aren't keeping around the Lua state between renders
        clear_alarm
        close
        #puts "<< END LAMINATE RENDER. Enabling gc."
        #GC.enable
      end
    end

    # The State's logger can be overwritten if
    def logger=(logger)
      @logger = logger
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    protected

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
      BLACKLIST.each do |badfunc|
        eval("#{badfunc} = nil")
      end
      eval("function string.rep(count) return 'rep not supported'; end")
      if @@enable_timeouts
        init_lua_alarm
      end
    end

    def load_helpers(helpers)
      view = LuaView.new
      (helpers || []).each do |helper|
        if helper.is_a?(Module)
          LuaView.send(:include, helper)
          self.bind_lua_funcs(view, helper.public_instance_methods(false), helper, view)
          nil
        else
          self.bind_lua_funcs(helper, helper.class.public_instance_methods(false), helper.class, view)
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

    def setup_builtin_funcs
      self.function 'debug_all' do
        "<pre>Functions:\n  " +
        @helper_methods.join("\n  ") +
        "\nData:\n" +
        @local_data.collect do |local|
          val = self[local]
          val = val.is_a?(String) ? val : (val.respond_to?(:to_h) ? val.to_h.inspect : val.to_s)
          "  #{local} = #{val}"
        end.join("\n") + "</pre>"
      end

      self.eval BUILTIN_FUNCTIONS
      self.eval @options[:vendor_lua] if @options[:vendor_lua]
    end

    def bind_lua_funcs(target, methods, source_module, view)
      methods.each do |meth|
        argument_count = target.method(meth).arity
        if argument_count < 0
          raise "Ruby-style optional arguments for function '#{meth}' are not supported. Please use Javascript-style defaults instead."
        end

        # Save the ruby name so we can invoke it with 'send' in the Lua callback block
        ruby_method_name = meth.to_s.dup

        # Handle namespacing. This allows helpers to place functions under table containers.
        # So the helper:
        #   class Helper
        #     def self.namespaces; [:my]; end
        #
        #     def my_videos
        #       [...data...]
        #     end
        #   end
        #
        # will implement a Lua function available as "my.videos" which will call the "my_videos" function. Methods
        # are matched to namespaces by the prefix.
        namespaces = target.class.respond_to?(:namespaces) ? target.class.namespaces : []
        lua_post_func = target.class.respond_to?(:post_process_func) ? target.class.post_process_func(meth) : nil

        # Find namespaces matching the method, then return the longest one
        ns = namespaces.select {|ns| meth.gsub('_', '.').index("#{ns}.") == 0}.sort {|a, b| b.to_s.length <=> a.to_s.length}.first
        if ns
          meth = "#{ns}.#{ruby_method_name[ns.to_s.length+1..-1]}"
          ensure_namespace_exists(ns.to_s)
        end

        # Record for debugging purposes
        @helper_methods << "#{source_module}: #{meth}"
        setup_func_binding(target, meth.to_s, ruby_method_name, argument_count, view, lua_post_func)
      end

      return
    end

    # Binds the indicated ruby method into the Lua runtime. To support optional arguments,
    # a Lua "wrapper" function is created. So the call chain looks like:
    #
    #   <name>(arg1, arg2, ...)
    #     invokes <name>__
    #
    #   <name>__ => bound to Ruby block
    #
    # This allows us to use Lua's ability to ignore omitted arguments. Since our Ruby block must always
    # be passed the right number of args, our wrapper function has the effect of defining those missing
    # args as nil.

    def setup_func_binding(target, lua_name, ruby_name, argument_count, view, lua_post_func)
      ruby_bound_name = "#{lua_name}_r_"

      if argument_count > MAX_ARGUMENTS
        raise "Ack! Too many arguments to helper function #{ruby_name}: try using an options hash"
      end

      if !@wrap_exceptions
        self.function(lua_name) do |*args|
          target.send ruby_name, *fix_argument_count(argument_count, args)
        end
      else
        self.function(ruby_bound_name) do |*args|
          begin
            target.send ruby_name, *fix_argument_count(argument_count, args)
          rescue Exception => err
            logger.error(err.message)
            logger.error(err.backtrace.join("\n"))
            self.eval("_rb_error = [[#{err.message}]]")
            nil
          end
        end
        s_args = []; argument_count.times {|n| s_args << "arg#{n+1}"}; s_args  = s_args.join(",")
        self.eval("function #{lua_name}(#{s_args}) _rb_error = nil; return #{lua_post_func}(_rb_assert(#{ruby_bound_name}(#{s_args}), _rb_error)); end")
      end
    end

    # This ensures that the number of args given match the number of args expected
    # Something about this smells bad though
    def fix_argument_count(count, args)
      [0, count - args.length].max.times do
        args << nil
      end
      args
    end

    # Ensures that the Lua context contains nested tables matching the indicated namespace
    def ensure_namespace_exists(namespace)
      parts = namespace.split('.')
      0.upto(parts.size-1) do |idx|
        table = parts[0..idx].join('.')
        unless self[table]
          self.eval("#{table} = {}")
        end
      end
    end

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