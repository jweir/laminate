require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'lib/laminate/parser'

class Laminate::Parser::Test < Test::Unit::TestCase

  context "Laminate::Parser" do
    context "simple example" do
      setup do
        @result = Laminate::Parser.new("Hello <% 'World' %>")
      end

      should "have two elements" do
        assert_equal 2, @result.content.length
      end

      should "have a text and code elemnt" do
        assert_equal [:text, "Hello "], @result.content[0]
        assert_equal [:code, " 'World' "], @result.content[1]
      end
    end

    context "without code" do
      should "parse" do
        assert_equal [[:text, "<h1>Hello</h1> World"]], Laminate::Parser.new("<h1>Hello</h1> World").content
      end

      should "parse when staring with an HTML comment" do
        assert_equal [[:text, "<!-- Comment --> ok"]], Laminate::Parser.new("<!-- Comment --> ok").content
      end
    end

    context "without text" do
      should "parse" do
        assert_equal [[:code, " code "]], Laminate::Parser.new("<% code %>").content
      end
    end

    context "a multiline example" do
      setup do
        @result = Laminate::Parser.new((<<-TXT).strip
        Hello <%
          x = 1
          y = 2
        %> World
        TXT
        )
      end

      should "have three elements" do
        assert_equal 3, @result.content.length
      end

      should "have two text elements" do
        assert_equal [:text, "Hello "], @result.content[0]
        assert_equal [:text, " World"], @result.content[2]
      end

      should "have one code element" do
        assert_equal :code, @result.content[1].first
        assert_match /x = 1\s+y = 2\s+/m, @result.content[1].last
      end
    end

    context "code elements" do
      setup do
        @result = Laminate::Parser.new "<% code %> text <%= print %><% code_2 %>"
      end

      should "have code elements" do
        assert_equal :code, @result.content[0].first
        assert_equal :code, @result.content[3].first
      end

      should "have print elements" do
        assert_equal :print, @result.content[2].first
        assert_equal " print ", @result.content[2].last
      end
    end
  end

end
