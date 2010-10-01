require 'cgi'

module Laminate
  class TemplateError < RuntimeError

    def initialize(error_message, template_name, template_parsed)
      @error_message   = error_message
      @template_name   = template_name
      @source          = (template_parsed || '')
    end

    # false for the root template
    def included_template?
      !included_template.nil?
    end

    def template_name
      (included_template || [@template_name])[-1]
    end

    def lua_line_offset
      included_template? ? 0 : -2
    end

    def line_number
      @line_number ||= begin
        if @error_message =~ /line (\d+)/
          $1.to_i
        elsif @error_message =~ /:(\d+):/
          $1.to_i + lua_line_offset
        else
          -1
        end
      end
    end

    def line_label
      line_number >= 0 ? line_number.to_s : '?'
    end

    def col_number
      if @error_message =~ /column (\d+)/
        $1.to_i
      else
        1
      end
    end

    def message
      if @error_message =~ /expecting kEND/
        "expecting {{end}} tag"
      else
        @error_message.match(/:\d+:(.*)\([123]\)/)[1].strip.gsub(/'{2,}/,"'")
      end
    end

    def sanitize(str)
      (str || '').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def to_s
      "Template '#{@name}' returned error at line #{line_label}: #{message}\n\nExtracted source\n#{extract}"
    end

    def to_html
      <<-HTML
<div class='error'>
<h1>Error in template <em>#{@template_name}</em> on line #{line_number}</h1>
<div class='message'>#{message}</div>
</div>
      HTML
    end

    protected

    def included_template
      @error_message.match(/'included: '(.[^']*)':/)
    end
  end
end
