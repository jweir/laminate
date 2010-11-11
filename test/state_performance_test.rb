require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require 'benchmark'
require 'laminate'
require 'shoulda'

class StatePerformanceTest < Test::Unit::TestCase
  include Laminate

  class TestHelpers
    def run(table, key)
      table[key].to_s << " ok"
    end
  end

  context "simple performance" do
    setup do
      @count = 250
    end

    should "perform a simple task" do
      puts " "
      Benchmark.bm do |x|
        x.report do
          for i in 1..@count do
            state = State.new(
                      :timeout => 12,
                      :locals => {"a_table" => {:a => "A", :b => "B", :c => "C"}})
            state.run {|s| s.eval(%{a_table.a})}
          end
        end
      end
    end

    should "perform a with ruby helpers" do
      puts " "
      Benchmark.bm do |x|
        x.report do
          for i in 1..@count do
            state = State.new(
                      :timeout => 12,
                      :helpers => { :test => TestHelpers.new },
                      :locals => {"a_table" => {:a => "A", :b => "B", :c => "C"}})
            state.run {|s| s.eval(%{test.run(a_table, "b")})}
          end
        end
      end
    end
  end
end
