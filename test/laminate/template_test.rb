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
          :text => 'Hello <%= vendor.world() %>, today is <%= text %> and I am <%= #{1,2,3} %> years old.',
          :vendor_lua => "vendor = { world = function() return 'World'; end }"
          )
    end

    should "allow injecting additional functions and properties" do
      assert_equal "Hello World, today is great and I am 3 years old.", @lam.render(:locals => {:text => "great"}).strip
    end
  end

  context "error handeling" do
    should "convert Ruby exception into TemplateError" do
      lam = Laminate::Template.new(:text => "line 1\nline 2\n<% raises_error() %>", :logger => Logger.new("/dev/null"))
      result = lam.render(:helpers => [SampleHelper.new])
      assert_match /line 3/i, result
      assert_match /Error/, result
      assert_match /Exception/, result
    end

    context "from the root template" do
      setup do
        mock_file :expects, "/tmp/root.lam", "line 1\n\n\n<% error_on_line_2 error %>"
        @template = Laminate::Template.new(:file => "/tmp/root.lam")
      end

      should "generate a TemplateError" do
        mock_error = mock(:to_html => "error message")
        Laminate::TemplateError.expects(:new).with(regexp_matches(/(\]:6:).*(near 'error'')/),"root.lam",kind_of(Array)).returns(mock_error)
        assert_equal "error message", @template.render
      end
    end

    context "from an included template" do
      setup do
        mock_file :expects, "/tmp/root.lam", "line 1\n<% include('partial') %>"
        mock_file :expects, "/tmp/partial.lam", "line 1\nline 2\n\n\n\n<% error_on_line_3 partial_error %>"
        @template = Laminate::Template.new(:file => "/tmp/root.lam")
      end

      should "generate a TemplateError for the included template" do
        mock_error = mock(:to_html => "error message")
        Laminate::TemplateError.expects(:new).with(regexp_matches(/(included: 'partial').*(\]:7:).*(near 'partial_error'')/ ), "root.lam",kind_of(Array)).returns(mock_error)
        assert_equal "error message", @template.render
      end
    end
  end


  context "loading a template file" do
    setup do
      mock_file :expects, "/tmp/root.lam", "<%= include('child') %> <%= root_variable %>"
      mock_file :expects, "/tmp/child.lam", "child is <%= child_variable %> <%= include('grandchild') %>"
      mock_file :expects, "/tmp/grandchild.lam", "grandchild is <%= grandchild_variable %>"
    end

    should "render the template and included templates" do
      lam = Laminate::Template.new(:file => "/tmp/root.lam")
      res = lam.render(:locals => {:root_variable => "root", :child_variable => "included", :grandchild_variable => "felix"})
      assert_match /root/, res
      assert_match /child is included/, res
      assert_match /grandchild is felix/, res
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

    def raises_error
      raise Exception
    end
  end

end
