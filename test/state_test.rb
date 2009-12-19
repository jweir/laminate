require File.expand_path(File.dirname(__FILE__) + '/helper')
require 'logger'
require 'laminate'
require 'shoulda'
require 'laminate/timeouts'

class StateTest < Test::Unit::TestCase
  include Laminate

  module TestHelpers
    def helper_method(str)
      ["head", str].join(" ")
    end
  end

  context "options" do
    setup do
      @state = State.new(
                :timeout => 12,
                :locals => {:hello => "world"},
                :helpers => [TestHelpers])
    end

    should "have the time set" do
      assert_equal 12, @state.timeout
    end

    should "bind locals" do
      assert_equal "world", @state.run {|s| s.eval(%{return hello})}
    end

    should "bind helpers" do
      assert_equal "head tail", @state.run {|s| s.eval(%{return helper_method("tail")})}
    end
  end

  context "#run" do

    should "allow overwritting the #logger during a run" do
      state = State.new
      state.run {|s| s.logger = :my_logger}
      assert_equal :my_logger, state.logger
    end

    should "#eval the given Lua code" do
      res =  State.new.run do |state|
        state.eval("function x() return 'yes' end")
        state.eval("return x()")
      end
      assert_equal "yes", res
    end

     should "allow binding functions via #function" do
       res =  State.new.run do |state|
         state.function 'join' do |str| ["head", str].join(" "); end
         state.eval("return join('tail')")
       end
       assert_equal "head tail", res
     end
  end


  context "builtin functions" do
    should "have string.escape" do
      assert_equal "&quot;string&quot;", State.new.run { |s| s.eval %{ return string.escape('"string"')}""}
    end
  end

  context "errors" do
    should "raise errors" do
      assert_raise Rufus::Lua::LuaError do
        State.new.run {|s| s.eval("function { wrong syntax}")}
      end
    end

    should "call the provided error_handler proc, if it exists" do
      error_handler = Proc.new {|err| raise RuntimeError}
      assert_raise RuntimeError do
        State.new.run(error_handler) {|s| s.eval("function { wrong syntax}")}
      end
    end
  end

  context "timeouts" do
    setup do
      @loop = %{for i=1,1e12 do f = 'hello'; end}
    end

    should "use the default timeout" do
      start = Time.now
      assert_raise Rufus::Lua::LuaError do
        State.new.run {|s| s.eval(@loop)}
      end
      assert_in_delta 15.0, (Time.now - start), 0.5
    end

    should "use a given timeout" do
      start = Time.now
      assert_raise Rufus::Lua::LuaError do
        State.new(:timeout => 3).run {|s| s.eval(@loop)}
      end
      assert_in_delta 3.0, (Time.now - start), 0.5
    end
  end

end