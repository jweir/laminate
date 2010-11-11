require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'logger'
require 'laminate'

class Laminate::Compiler::Test < Test::Unit::TestCase
  include Laminate

  context "Laminate::Compiler" do

    setup do
      @compiler = Laminate::Compiler.new
    end

    should "handle strings, code and printable code" do
      result = @compiler.compile "test", [[:text, "Hello "], [:code, "x = 'world'"], [:print, "x"]]
      assert_equal "Hello world", render(result)
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
      result = @compiler.compile "test", [
        [:text, "[[Hello]]\nworld "], [:code, "x = 'again'\ny = 'ok'"], [:print, "x\ny"]]

      output = render(result)
      assert_match "[[Hello]]\nworld again", output
    end

    should "handle quotes and ticks" do
      result = @compiler.compile "test", [[:text, "My name is 'code'"]]
      assert_equal "My name is 'code'", render(result)
    end
  end

  def render(code)
    State.new.run {|s|
      s.eval code
      s.eval "_template_test()"
    }
  end
end
