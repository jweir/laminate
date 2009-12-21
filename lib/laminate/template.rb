require 'logger'

module Laminate

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

    # Runs the render and raises errors
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
      error_proc = Proc.new {|err| handle_error(err, lua, options)}

      State.new(options).run(error_proc) do |state|
        state.logger = logger
        state.eval(lua)
        # Included template functions. The trick is that we don't return to Ruby and eval the included template, because the
        # Lua binding doesn't like re-entering eval. So instead we bind a function '_load_template' which returns the template
        # code, and then we eval it inside Lua itself using 'loadstring'. Thus the template 'include' function is actually
        # a native Lua function.
        state.function '_load_template' do |template_name|
          prepare_template(template_name)
          load_template_innerds(template_name)
        end

        state.eval("return #{@compiler.lua_template_function(name)}()")
      end
    end

    protected

    # Returns the kind of template based upon the options
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

    # Compiles the indicated template if needed
    def prepare_template(name)
      if @loader.needs_compile?(name)
        lua = @compiler.compile(name, @loader.load_template(name))
        @loader.save_compiled(name, lua)
      end
    end

    # Returns just the body of the template function
    def load_template_innerds(name)
      body = @loader.load_compiled(name)
      body.split("\n")[1..-2].join("\n")
    end

    def handle_error(err, lua, options)
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
      if options[:raise_errors]
        raise wrapper
      else
        @errors << wrapper
        return wrapper.to_html
      end
    end

  end #class Template
end
