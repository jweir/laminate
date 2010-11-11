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
  # == Vendor
  # include the option :vendor => string to add addtional Javsacript functions or properties into the template
  #
  #    template = Laminate::Template.new(:name => "template1", :vendor=> "vendor_test = function() {return true};")
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

      @vendor = options[:vendor]
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

    # Returns the text of the rendered template.
    # See @Laminate::State for options
    def render(options = {})
      options.merge! :vendor=> @vendor
      name = @name.dup
      template_code = prepare_template(name)

      begin
        State.new(options).run do |state|
          state.logger = logger

          state['include'] = lambda do |template_name|
            compiled = prepare_template(template_name)
            state.eval compiled
            state.eval("#{@compiler.out_template_function(template_name)}()")
          end

          state.eval(template_code)
          state.eval("#{@compiler.out_template_function(name)}()")
        end
      rescue V8::JSError, Laminate::Loader::MissingFile => err
        error = TemplateError.new(err, name, template_code)
        if options[:raise_errors]
          raise error
        else
          return error.to_html
        end
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
      else
        nil
      end
    end

    # Compiles the indicated template if needed
    def prepare_template(name)
      source  = @loader.load_template(name)
      parsed  = Laminate::Parser.new(source).content
      comiled = @compiler.compile(name, parsed)
    end

  end
end
