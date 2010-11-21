require 'cgi'

module Laminate
  class TemplateError < RuntimeError

    attr_reader :error, :template_name, :template_parsed

    def initialize(error, template_name, template_parsed)
      @error           = error
      @error_message   = error.message
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
      # @error_message.match(/\]:\d+:(.*)(\([123]\))?/)[1].gsub(/'{2,}/,"'").gsub(/\([123]\)/,"").strip
      @error_message
    end

    def source
      out = []
      Laminate::Parser.unparse(@source).each_line.with_index.map do |line, i|
        out = sanitize(line)
        i+1 == line_number ? "<b><em>#{out}</em></b>" : out
      end.join
    end

    def line_number
      if @error.in_javascript?
        @error.backtrace.first.scan(/<eval>:([0-9]+)/).to_s.to_i - 1
      else
        0
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

