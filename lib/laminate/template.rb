require 'logger'

module Laminate

  # Create a Template so that you can render it. A Template is created by either passing in the text of the template,
  # or by passing in a #Loader instance which knows how to load templates.
  #
  # Examples:
  #    template = Laminate::Template.new(:text => "<h1>Hello <%= user.name %></h1>")
  #
  #    template = Laminate::Template.new(:file => "my/template/path/template1.lam")
  # Will load templates from the indicated directory, named by their file names.
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
  #
  # == Vendor Lua
  # include the option :vendor_lua => string to add addtional Lua functions or tables into the template
  #
  #    template = Laminate::Template.new(:name => "template1", :vendor_lua => "vendor_test = function() return true end")
  #
  class Template

    attr_accessor :errors

    def initialize(options = {})
      @logger = options[:logger]
      @compiler = Compiler.new

      case template_kind(options)
      when :file then
        @name    = options[:file]
        view_dir = File.dirname(@name)
        @name    = File.basename(@name)
        @loader  = Loader.new(File.expand_path(view_dir), 'lam')
      when :loader then
        @name   = options[:name]
        @loader = options[:loader]
      when :text then
        @loader = InlineLoader.new(options[:text])
        @name   = "inline"
      else
        @name   = "inline"
        @loader = InlineLoader.new("No template supplied")
      end

      @vendor_lua = options[:vendor_lua]
      # Some recordings for debug purposes
      @helper_methods = []
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    # Runs the render and raises errors
    def render!(options = {})
      render(options.merge(:raise_errors => true))
    end

    # Renders the template assigned at construction. Options include:
    #   :locals          -> A hash of variables to make available to the template (simply types, Hashes, and Arrays only. Nesting OK)
    #   :helpers         -> An array of Modules or instances to make available as functions to the template.
    #   :raise_errors    -> (true|false) If true, then errors raise an exception. Otherwise an error message is printed as the template result.
    #   :wrap_exceptions -> (*true|false) If true, then Ruby exceptions are re-raised in Lua. This incurs a small performance penalty.
    #   :timeout         -> Max run time in seconds for the template. Default is 15 secs.
    #
    # Returns the text of the rendered template.
    def render(options = {})
      options.merge! :vendor_lua => @vendor_lua if @vendor_lua
      name = @name.dup
      compiled, parsed, source = prepare_template(name)

      error_wrap(name, parsed, options[:raise_errors]) do
        State.new(options).run do |state|
          state.logger = logger
          state.eval(compiled)
          # Included template functions. The trick is that we don't return to Ruby and eval the included template, because the
          # Lua binding doesn't like re-entering eval. So instead we bind a function '_load_template' which returns the template
          # code, and then we eval it inside Lua itself using 'loadstring'. Thus the template 'include' function is actually
          # a native Lua function.
          state.function '_load_template' do |template_name|
            _compiled, _parsed, _source = prepare_template(template_name)
            load_template_innerds(_compiled)
          end

          state.function '_included_template_error' do |template_name, message|
            included_template_error(template_name, message)
          end

          state.eval("return #{@compiler.lua_template_function(name)}()")
        end
      end
    end

    protected

    def error_wrap(template_name, template_parsed, raise_error = false)
      begin
        yield
      rescue TemplateError => error
        return error.to_html
      rescue Rufus::Lua::LuaError, Laminate::Loader::MissingFile => exception
        error = TemplateError.new(exception.message, template_name, template_parsed)
        raise error if raise_error
        return error.to_html
      end
    end

    def included_template_error(template_name, message)
      compiled, parsed, source = prepare_template(template_name)
      raise TemplateError.new(message, template_name, parsed)
    end

    # Returns the kind of template based upon the options
    def template_kind(options)
      if options[:file]
        :file
      elsif options[:name] && options[:loader]
        :loader
      elsif options[:text]
        :text
      else
        nil
      end
    end

    # Compiles the indicated template if needed
    def prepare_template(name)
      source   = @loader.load_template(name)
      parsed   = Laminate::Parser.new(source).content
      compiled = @compiler.compile(name, parsed)
      [compiled, parsed, source]
    end

    # Returns just the body of the template function
    def load_template_innerds(body)
      body.split("\n")[1..-2].join("\n")
    end

  end
end
