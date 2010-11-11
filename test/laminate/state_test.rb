require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'logger'
require 'laminate'

class Laminate::StateTest < Test::Unit::TestCase
  include Laminate

  class TestHelpers
    def join(str)
      ["head", str].join(" ")
    end
  end

  def should_raise_error(code)
    assert_raise Laminate::TemplateError, "#{code} should have raised an error" do
      Laminate::Template.new(:text => code, :logger => @logger).render(:raise_errors => true)
    end
  end

  context "simplest thing possible" do
    should "print a string" do
      assert_equal "hello", State.new.run {|s| s.eval("'hello'")}
    end

    should "do math" do
      assert_equal 2, State.new.run {|s| s.eval("1+1")}
    end

    should "call a function" do
      assert_equal 'returned', State.new.run {|s| s.eval("function n(f){return f}; n('returned')")}
    end
  end

  context "bindings" do
    setup do
      @state = State.new(
                :locals => {:hello => "world"},
                :helpers => { :helper => TestHelpers.new })
    end

    should "bind locals" do
      assert_equal "world", @state.run {|s| s.eval(%{hello})}
    end

    should "bind helpers" do
      assert_equal "head tail", @state.run {|s| s.eval(%{helper.join("tail")})}
    end
  end

  context "#run" do

    should "allow overwritting the #logger during a run" do
      state = State.new
      state.run {|s| s.logger = :my_logger}
      assert_equal :my_logger, state.logger
    end

    should "#eval the given Javascript code" do
      res =  State.new.run do |state|
        state.eval("function x() { return 'yes'}")
        state.eval("x()")
      end
      assert_equal "yes", res
    end

     should "allow binding functions via #function" do
       res =  State.new.run do |state|
         state['join'] = lambda do |str| ["head", str].join(" "); end
         state.eval("join('tail')")
       end
       assert_equal "head tail", res
     end
  end

  context ":scope" do
    setup do
      class TestScope
        def print(x)
          "I printed #{x}"
        end
      end

      @state = State.new :scope => TestScope.new 
    end

    should "give a global context" do
      assert_equal "I printed scope", @state.eval("print('scope')")
    end
  end

  context "vendor options" do
    setup do
      @state = State.new(
                :locals => {:hello => "world"},
                :vendor => "function vendor(str){ return 'vendor function ' + str }")
    end

    should "allow adding additional functions to the state" do
      assert_equal "vendor function world",  @state.run { |s| s.eval %{ vendor(hello)}""}
    end
  end

  context "errors" do
    should "raise V8::JSError with bad syntax" do
      assert_raise V8::JSError do
        State.new.run {|s| s.eval("function { wrong syntax}")}
      end
    end
  end

end
