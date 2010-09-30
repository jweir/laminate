require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'logger'
require 'laminate'
require 'laminate/timeouts'

class Laminate::TemplateTest < Test::Unit::TestCase
  include Laminate

  # TODO create tests
  context "loaders" do
    context "file" do
    end
    context "text" do
    end
    context "custom" do
    end
  end

  context "a simple template" do
    setup do
      @lam = Laminate::Template.new :text => "Hello <% x = 'World' %><%= x %>"
    end

    should "render" do
      assert_equal "Hello World", @lam.render
    end
  end

  context "vendor_lua" do
    setup do
      @lam = Laminate::Template.new(
          :text => "Hello <%= vendor.world() %>, today is <%= text %>",
          :vendor_lua => "vendor = { world = function() return 'World'; end }"
          )
    end

    should "allow injecting additional functions and properties" do
      assert_equal "Hello World, today is great", @lam.render(:locals => {:text => "great"}).strip
    end
  end


  context "loading a template file" do

    setup do
      mock_file :expects, "/tmp/root.lam", "<%= include('child') %> <%= root_variable %>"
      mock_file :expects, "/tmp/child.lam", "<%= child_variable %>"
    end

    should "render the template and included templates" do
      lam = Laminate::Template.new(:file => "/tmp/root.lam")
      res = lam.render(:locals => {:root_variable => "root", :child_variable => "included"})
      assert_match /root/, res
      assert_match /included/, res
    end
  end

  context "helper functions" do

    should "allow root methods" do
      lam = Laminate::Template.new :text => "Hello <%= root() %>"
      assert_equal "Hello root", lam.render(:helpers => [SampleHelper.new])
    end

    should "allow namespaced methods" do
      lam = Laminate::Template.new :text => "Hello <%= test.func() %>"
      assert_equal "Hello namespaced", lam.render(:helpers => [SampleHelper.new])
    end

    should "eval methods with args" do
      lam = Laminate::Template.new :text => "Hello <%= args('world') %>"
      assert_equal "Hello world", lam.render(:helpers => [SampleHelper.new])
    end
  end

  class SampleHelper < Laminate::AbstractLuaHelper
    namespace 'test'

    def args(a)
      a
    end

    def root
      "root"
    end

    def test_func
      "namespaced"
    end
  end

end
