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
      included_template.nil?
    end

    def template_name
      @template_name
    end

    def message
      if @error_message =~ /expecting kEND/
        "expecting {{end}} tag"
      else
        @error_message.match(/\]:\d+:(.*)(\([123]\))?/)[1].gsub(/'{2,}/,"'").gsub(/\([123]\)/,"").strip
      end
    end

    def source
      out = []
      Laminate::Parser.unparse(@source).each_line.with_index.map do |line, i|
        out = sanitize(line)
        i+1 == line_number ? "<b><em>#{out}</em></b>" : out
      end.join
    end
    def lua_line_offset
      -2
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

    def to_html
      <<-HTML
<div class='error'>
<h1>Error in template <em>#{@template_name}</em> on line #{line_number}</h1>
<div class='message'>#{message}</div>
<pre><code>
#{source}
</code></pre>
</div>
      HTML
    end

    protected

    def line_label
      line_number >= 0 ? line_number.to_s : '?'
    end

    def sanitize(str)
      (str || '').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def included_template
      @error_message.match(/^eval:compile/)
    end
  end
end
