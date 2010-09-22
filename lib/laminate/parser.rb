require 'treetop'
require 'polyglot'
require 'lib/laminate/grammar'

module Laminate
  class Parser
    attr_accessor :parser, :parsed

    def initialize(source)
      self.parser = GrammarParser.new
      self.parsed = self.parser.parse(source)
    end

    def content
      self.parsed.content
    end

  end
end
