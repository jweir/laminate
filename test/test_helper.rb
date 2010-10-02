require 'test/unit'
require 'rubygems'
require 'shoulda'
require 'mocha'
require 'ruby-debug'

module Test::Fixtures

  def fixture_path(file_name)
    File.expand_path(File.dirname(__FILE__) + "/fixtures/#{file_name}")
  end

  def fixture(file_name)
    File.read fixture_path(file_name)
  end
end


# Add Rails-style declarative test syntax
class Test::Unit::TestCase
  include Test::Fixtures

  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
    defined = instance_method(test_name) rescue false
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method(test_name, &block)
    else
      define_method(test_name) do
        flunk "No implementation provided for #{name}"
      end
    end
  end

  def mock_file(method, filename, contents)
    File.send(method, :exist?).with(filename).returns true
    File.send(method, :open).with(filename).returns mock(:read => contents)
  end

  class MockLoader

    def initialize(templates)
      @templates = templates
    end

    def load_template(name)
      @templates[name.to_sym]
    end
  end
end

$:.unshift(File.join(File.dirname(__FILE__), '../lib'))
require 'laminate'

# Look for Rufus-Lua parallel to Laminate (as in vendor/plugins),
# otherwise it must be installed as a gem.
rufus_dir = File.join(File.dirname(__FILE__), '../../rufus-lua/lib')
if File.exist?(rufus_dir)
  $:.unshift(rufus_dir)
end
