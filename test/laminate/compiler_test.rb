require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'logger'
require 'laminate'
require 'laminate/timeouts'

class Laminate::Compiler::Test < Test::Unit::TestCase
  include Laminate

  context "Laminate::Compiler" do

    setup do
      @compiler = Laminate::Compiler.new
      @result = @compiler.compile "test", [[:text, "Hello "], [:code, "x = 'world'"], [:print, "x"]]
    end

    should "create a Lua function which can be run through State" do
      assert_equal "Hello world", render(@result)
    end

    should "compile print code only" do
      result = @compiler.compile "test", [[:print, "'code'"]]
      assert_equal "code", render(result)
    end

    should "compile code & print only" do
      result = @compiler.compile "test", [[:code, "x = 1;"], [:print, "x"]]
      assert_equal "1", render(result)
    end

    should "handle multi line calls" do
      @result = @compiler.compile "test", [
        [:text, "[[Hello]]
          world "], [:code, "x = 'again'
          y = 'ok'"], [:print, "x
          y"]]

      output = render(@result)
      assert_match /\[\[Hello\]\]\n\s+world again/, output
    end
  end

  def render(code)
    State.new.run {|s|
      s.eval code
      s.eval "return _template_test()"
    }
  end
end
