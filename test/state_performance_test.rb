require File.expand_path(File.dirname(__FILE__) + '/helper')
require 'benchmark'
require 'laminate'
require 'shoulda'
require 'laminate/timeouts'

class StatePerformanceTest < Test::Unit::TestCase
  include Laminate

  module TestHelpers
    def helper_method(table, key)
      table[key].to_s << " ok"
    end
  end

  context "simple performance" do
    setup do
      @count = 1000
    end

    should "perform a simple task" do
      Benchmark.bm do |x|
        x.report do
          for i in 1..@count do
            state = State.new(
                      :timeout => 12,
                      :locals => {"a_table" => {:a => "A", :b => "B", :c => "C"}})
            state.run {|s| s.eval(%{return a_table.a})}
          end
        end
      end
    end

    should "perform a with ruby helpers" do
      Benchmark.bm do |x|
        x.report do
          for i in 1..@count do
            state = State.new(
                      :timeout => 12,
                      :helpers => [TestHelpers],
                      :locals => {"a_table" => {:a => "A", :b => "B", :c => "C"}})
            state.run {|s| s.eval(%{return helper_method(a_table, "b")})}
          end
        end
      end
    end
  end
end