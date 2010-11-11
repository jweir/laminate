require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'logger'
require 'laminate'

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

  context "vendor" do
    setup do
      @lam = Laminate::Template.new(
          :text   => "Hello <%= vendor.world() %>, today is <%= text %>",
          :vendor => "vendor = { world : function() {return 'World';}}"
          )
    end

    should "allow injecting additional functions and properties" do
      assert_equal "Hello World, today is great", @lam.render(:locals => {:text => "great"}).strip
    end
  end

  context "loading a template file" do

    setup do
      mock_file :expects, "/tmp/parent.lam", "<%= parent %> <%= include('child') %>"
      mock_file :expects, "/tmp/child.lam", "<%= child %> <%= include('grand_child') %>"
      mock_file :expects, "/tmp/grand_child.lam", "<%= grand_child %>"
    end

    should "render the template and included templates" do
      lam = Laminate::Template.new(:file => "/tmp/parent.lam")
      res = lam.render(:locals => {:parent => "parent", :child => "child", :grand_child => "grand child"})
      assert_match "parent child grand child", res
    end
  end

  context "helper functions" do

    should "allow property accessor" do
      lam = Laminate::Template.new :text => "Hello <%= helper.root %>"
      assert_equal "Hello root", lam.render(:helpers => {:helper => SampleHelper.new })
    end

    should "eval methods with args" do
      lam = Laminate::Template.new :text => "Hello <%= helper.args('world') %>"
      assert_equal "Hello world", lam.render(:helpers => { :helper => SampleHelper.new })
    end
  end

  class SampleHelper < Laminate::AbstractLuaHelper

    def args(a)
      a
    end

    def root
      "root"
    end

  end

end
