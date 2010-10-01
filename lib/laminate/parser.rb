require 'treetop'
require 'polyglot'
require 'laminate/grammar'

module Laminate
  class Parser
    attr_accessor :parser, :parsed

    def self.unparse(parsed_code)
      parsed_code.map do |el|
        case el.first
        when :text
          then el.last
        when :code
          then %{<%#{el.last}%>}
        when :print
          then %{<%=#{el.last}%>}
        end
      end.join.gsub(/\\n/,"\n")
    end

    def initialize(source)
      self.parser = GrammarParser.new
      self.parsed = self.parser.parse(source)
    end

    def content
      self.parsed.content
    end
  end
end
