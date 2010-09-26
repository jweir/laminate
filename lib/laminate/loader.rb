require 'lib/laminate/parser'

module Laminate
  # Sample class for loading Laminate templates, loads them off the filesystem.
  class Loader
    # Default loader expects to load Laminate templates from the given directory by name (where names
    # can include relative paths).
    def initialize(basedir, extension = 'lam')
      @extension = extension
      @base = basedir || File.expand_path(".")
      raise "Invalid template directory '#{@base}'" unless File.directory?(@base)
    end

    # Load the Laminate template with the given name. Will look in <tt>basedir/name.lam</tt>.
    # Returns the template content as a string.
    def load_template(name)
      f = lam_path(name)
      if File.exist?(f)
        File.open(f).read
      else
        raise "Missing template file #{f}"
      end
    end

    private
      def lam_path(name)
        fname = (name =~ /\.#{@extension}$/) ? name : "#{name}.#{@extension}"
        (fname =~ /^\// or fname =~  /^.:\//) ? fname : File.join(@base, fname)
      end
  end

  # Implements a simple in memory template loader which operates in memory. 
  class InlineLoader < Loader

    def initialize(content)
      @content = content 
    end

    def load_template(name = nil)
      @content
    end
  end

end
