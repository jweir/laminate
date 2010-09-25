require File.expand_path(File.dirname(__FILE__) + '/helper')
require 'laminate'
require 'erb'

class PerformanceTest

  include Test::Fixtures

  def initialize
    @count = 250
    lam = laminate_test
    erb = erb_test
    if ENV["COMPARE"] && lam.strip != erb.strip
      puts "Ack! Files are different"
      show_diff(lam, erb)
    end
  end

  # This is implemented just for ERB
  def include(name)
    erb = ERB.new(fixture("#{name}.erb"))
    erb.result(binding)
  end

  protected

  def show_diff(left, right)
    t1 = File.open("/tmp/lamoutput", "w")
    t1.write(left)
    t1.close
    t2 = File.open("/tmp/erboutput", "w")
    t2.write(right)
    t2.close
    puts system("diff /tmp/lamoutput /tmp/erboutput")
  end

  def benchmark(name, count = 1)
    runtimes = []
    count.times do
      start = Time.now.to_f
      yield
      runtimes << Time.now.to_f - start
    end

    total = runtimes.inject(0) {|total, rt| total+rt}
    avg   = total / runtimes.size.to_f
    msec  = avg * @count.to_f

    puts "#{name} took avergage of #{msec} millisecs for #{count} iterations"
  end

  def laminate_test
    template = Laminate::Template.new(:file => fixture_path("full_test.lam"), :clear => true)
    output = nil
    benchmark "Laminate template",@count do
      output = template.render(:timeout => 45, :wrap_exceptions => false)
    end
    output
  end

  def erb_test
    erb = ERB.new(fixture("full_test.erb"))
    output = nil
    benchmark "ERB template", @count do
      output = erb.result(binding)
    end
    output
  end
end

PerformanceTest.new
