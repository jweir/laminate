require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'logger'
require 'laminate'
require 'laminate/timeouts'

class Laminate::StateTest < Test::Unit::TestCase
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

  context "vendor_lua options" do
    setup do
      @state = State.new(
                :locals => {:hello => "world"},
                :vendor_lua => "function vendor(str) return 'vendor function '..str end")
    end

    should "allow adding additional Lua functions to the state" do
      assert_equal "vendor function world",  @state.run { |s| s.eval %{ return vendor(hello)}""}
    end
  end

  context "errors" do
    should "raise Rufus::Lua::LuaErr with bad syntax" do
      assert_raise Rufus::Lua::LuaError do
        State.new.run {|s| s.eval("function { wrong syntax}")}
      end
    end

    should "clear the alarm and close the state when an error occurs" do
      state = State.new
      state.expects(:clear_alarm)
      state.expects(:close)

      assert_raise Rufus::Lua::LuaError do
        state.run {|s| s.eval("function { wrong syntax}")}
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

  context "sandbox" do
    %w{arg dofile loadfile os package require}.each do |sandboxed_method|
      should "not allow calling of #{sandboxed_method}" do
        assert_nil Laminate::State.new(:timeout => 3).run {|s| s.eval %{return #{sandboxed_method}}}
      end
    end
  end

end
