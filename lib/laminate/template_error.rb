require 'cgi'

module Laminate
  class TemplateError < RuntimeError

    attr_accessor :error, :name, :source

    def initialize(err, template_name, template_src, logger = nil)

      @err = err
      @err = Exception.new(@err) if @err.is_a?(String)

      logger.error(@err) if logger

      @name            = template_name
      @source          = (template_src || '')
    end

    def line_number
      @line ||= begin
        message = @err.backtrace.first
        message.to_s.scan(/:([0-9]):/).first.to_s.to_i - 1
      end
    end

    def line_label
      line_number >= 0 ? line_number.to_s : '?'
    end

    def col_number
      if @err.message =~ /column (\d+)/
        $1.to_i
      else
        1
      end
    end

    def extract
      line = line_number
      if line >= 0
        if line < @source.size
          if line > 0
            [@source[line-1], highlight(@source[line]), @source[line+1].to_s].join("\n")
          else
            [highlight(@source[line]), @source[line+1].to_s].join("\n")
          end
        end
      else
        ''
      end
    end

    def highlight(line)
      res = line.to_s
      res << "\n"
      (col_number-1).times {res << '.'}
      res << "^\n"
      res
    end

    def message
      m = @err.message #+ " " + @err.backtrace.first
      # Strip Rufus::Lua error anotation to template error is easier to read
      if m =~ /:\d+:(.*)\([123]\)/
        m = $1
      end
      m
    end

    def sanitize(str)
      (str || '').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def to_s
      "Template '#{@name}' returned error at line #{line_label}: #{message}\n\nExtracted source\n#{extract}"
    end

    def to_html
      "Template '#{@name}' returned error at line #{line_label}: #{sanitize(message)}\n\nExtracted source\n<pre><code>#{sanitize(extract)}</code></pre>".gsub("\n","<br />")
    end
  end
end
