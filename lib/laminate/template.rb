begin
  require 'rufus/lua'
rescue Exception => err
  puts "Error, Laminate failed to load because Rufus/Lua failed to load: #{err.message}"
end

require 'logger'

module Laminate

  MAX_ARGUMENTS = 7 # The maximium number of arguments a function will take

  class LuaView
  end

  # Create a Template so that you can render it. A Template is created by either passing in the text of the template,
  # or by passing in a #Loader instance which knows how to load templates.
  #
  # Examples:
  #    template = Laminate::Template.new(:text => "<h1>Hello {{user.name}}</h1>")
  #
  #    template = Laminate::Template.new(:file => "my/template/path/template1.lam")
  # Will load templates from the indicated directory, named by their file names. Use :clear => true to delete compiled templates on the file system.
  #
  #    template = Laminate::Template.new(:name => "template1", :loader => my_loader_class)
  # Loads 'template1' by using the passed #Loader instance.
  #
  # Note that the template is not compiled until you call #render.
  #
  # == Included templates
  #
  # A template may call the 'include' function to include another template. This mechanism only works if
  # you have created the Template using either :loader or :file. The included template has the same access
  # to the current state as the parent template.
  class Template

    attr_reader :helper_methods
    attr_accessor :errors

    def initialize(options = {})
      @errors = []
      @logger = options[:logger]
      @compiler = Compiler.new

      case template_kind(options)
      when :file:
        @name    = options[:file]
        view_dir = File.dirname(@name)
        @name    = File.basename(@name)
        @loader  = Loader.new(File.expand_path(view_dir), 'lam')
        @loader.clear_cached_templates if options[:clear]
      when :loader
        @name   = options[:name]
        @loader = options[:loader]
      when :text
        @loader = InlineLoader.new(options[:text])
        @name   = "inline"
      when :string
        @loader = InlineLoader.new(options)
        @name   = "inline"
      else
        @name   = "inline"
        @loader = InlineLoader.new("No template supplied")
      end

      # Some recordings for debug purposes
      @helper_methods = []
    end

    def template_kind(options)
      if options[:file]
        :file
      elsif options[:name] && options[:loader]
        :loader
      elsif options[:text]
        :text
      elsif options.is_a?(String)
        :string
      else
        nil
      end
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def clear_cached_templates
      if @loader.respond_to?(:clear_cached_templates)
        @loader.clear_cached_templates
      end
    end

    def compile(name = nil)
      name ||= @name
      prepare_template(name)
      begin
        state = State.new
        state.eval(@loader.load_compiled(name))
        return true
      rescue Rufus::Lua::LuaError => err
        @errors << Laminate::TemplateError.new(err, name, @loader.load_template(name))
        return false
      end
    end

    def load_template(name)
      @loader.load_template(name)
    end

    def template_source(name)
      prepare_template(name)
      @loader.load_compiled(name)
    end

    def test_lua_compiler(str)
      @compiler.compile('test', str)
    end

    def render!(options = {})
      render(options.merge(:raise_errors => true))
    end

    # Renders the template assigned at construction. Options include:
    #   :locals -> A hash of variables to make available to the template (simply types, Hashes, and Arrays only. Nesting OK)
    #   :helpers -> An array of Modules or instances to make available as functions to the template.
    #   :raise_errors -> (true|false) If true, then errors raise an exception. Otherwise an error message is printed as the template result.
    #   :wrap_exceptions => (*true|false) If true, then Ruby exceptions are re-raised in Lua. This incurs a small performance penalty.
    #   :timeout -> Max run time in seconds for the template. Default is 15 secs.
    #
    # Returns the text of the rendered template.
    def render(options = {})
      #debugger
      #puts ">> LAMINATE RENDER START. Disabling gc."
      #GC.disable
      # Compile template if needed
      name = @name.dup
      prepare_template(name)
      lua = @loader.load_compiled(name).dup

      @errors = []
      @wrap_exceptions = !options[:wrap_exceptions].nil? ? options[:wrap_exceptions] : true

      State.new(options).run(self, lua) do |state|
        state.eval("return #{@compiler.lua_template_function(name)}()")
      end
    end

#  private

    # Compiles the indicated template if needed
    def prepare_template(name)
      if @loader.needs_compile?(name)
        lua = @compiler.compile(name, @loader.load_template(name))
        @loader.save_compiled(name, lua)
      end
    end

    def bind_lua_funcs(target, methods, source_module, state, view)
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
          ensure_namespace_exists(ns.to_s, state)
        end

        # Record for debugging purposes
        @helper_methods << "#{source_module}: #{meth}"
        setup_func_binding(target, meth.to_s, ruby_method_name, argument_count, state, view, lua_post_func)
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

    def setup_func_binding(target, lua_name, ruby_name, argument_count, state, view, lua_post_func)
      ruby_bound_name = "#{lua_name}_r_"

      if argument_count > MAX_ARGUMENTS
        raise "Ack! Too many arguments to helper function #{ruby_name}: try using an options hash"
      end

      if !@wrap_exceptions
        state.function(lua_name) do |*args|
          target.send ruby_name, *fix_argument_count(argument_count, args)
        end
      else
        state.function(ruby_bound_name) do |*args|
          begin
            target.send ruby_name, *fix_argument_count(argument_count, args)
          rescue Exception => err
            logger.error(err.message)
            logger.error(err.backtrace.join("\n"))
            state.eval("_rb_error = [[#{err.message}]]")
            nil
          end
        end
        s_args = []; argument_count.times {|n| s_args << "arg#{n+1}"}; s_args  = s_args.join(",")
        state.eval("function #{lua_name}(#{s_args}) _rb_error = nil; return #{lua_post_func}(_rb_assert(#{ruby_bound_name}(#{s_args}), _rb_error)); end")
      end
    end

    # Ensures that the Lua context contains nested tables matching the indicated namespace
    def ensure_namespace_exists(namespace, state)
      parts = namespace.split('.')
      0.upto(parts.size-1) do |idx|
        table = parts[0..idx].join('.')
        unless state[table]
          state.eval("#{table} = {}")
        end
      end
    end

    # Returns just the body of the template function
    def load_template_innerds(name)
      body = @loader.load_compiled(name)
      body.split("\n")[1..-2].join("\n")
    end

    def render_error(err, lua)
      i = 1
      log_code = '1 ' + lua.gsub("\n") { |m| "\n#{i+=1} " }
      logger.error "LUA ERROR: #{err}\nfrom template:\n#{log_code}"
      if err.message =~ /included template: '(.*?)'/
        # Lua-include function will generate an error message with the included template name, so
        # make sure to peg exception to that template
        name = $1
        wrapper = TemplateError.new(err, name, @loader.load_template(name), logger)
        wrapper.lua_line_offset = 0
        logger.error "Created Template Error wrapper:\n#{wrapper.to_html}"
      else
        wrapper = TemplateError.new(err, @name, @loader.load_template(@name), logger)
      end
    end

    protected

    # This ensures that the number of args given match the number of args expected
    # Something about this smells bad though
    def fix_argument_count(count, args)
      [0, count - args.length].max.times do
        args << nil
      end
      args
    end


  end #class Template
end
