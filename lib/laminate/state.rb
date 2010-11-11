module Laminate

  require 'v8'

  class State < V8::Context

    # Is passed the options from Template#render
    #   :scope           -> An object to give global scope to the state
    #   :locals          -> A hash of variables to make available to the template (simply types, Hashes, and Arrays only. Nesting OK)
    #   :helpers         -> An hash of instances to make available as functions to the template.
    #   :wrap_exceptions -> (*true|false) If true, then Ruby exceptions are re-raised in Lua. This incurs a small performance penalty.
    #   :vendor          -> A string of additional Javascript functions
    def initialize(options = {})
      super :with => options[:scope]

      @wrap_exceptions = !options[:wrap_exceptions].nil? ? options[:wrap_exceptions] : true
      @helper_methods  = []
      @options         = options
    end

    # This block yeilds the state for eval and function adding
    # It closes the state at the end of the block
    def run
      begin
        # setup_builtin_funcs
        self.eval( @options[:vendor] || "" )
        bind @options[:locals]
        bind @options[:helpers]

        yield self
      ensure
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

    def bind(hash)
      (hash || {}).each { |k,v| self[k] = v }
    end
  end
end
