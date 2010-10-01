# FIXME this test is basically broken
require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'logger'
require 'laminate'

module TestFuncs
  def func_raises_error
    raise "Error, you no call this func!"
  end

  def post_processed_func(arg1, arg2)
    raise "Ruby-land error from: #{arg1}, #{arg2}"
  end
end

class Laminate::TemplateErrorTest < Test::Unit::TestCase

  context "Laminate::TemplateError" do
    context "any error" do
      setup do
        @error = Laminate::TemplateError.new \
          "eval:compile : '[string \'line\']:6: '=' expected near 'error'' (3)",
          'root.lam', [[:text, 'line 1\n\n\n'], [:code, ' error_on_line_2 error ']]
      end

      should "be renderable as html" do
        assert_equal html_sample, @error.to_html
      end
    end

    context "from a root template" do
      setup do
        @error = Laminate::TemplateError.new \
          "eval:compile : '[string \'line\']:6: '=' expected near 'error'' (3)",
          'root.lam', [[:text, 'line 1\n\n\n'], [:code, ' error_on_line_2 error ']]
      end

      should "have a template name" do
        assert_equal "root.lam", @error.template_name
      end

      should "not be flagged included?" do
        assert !@error.included_template?
      end

      should "have a line number for the error (offset with the Lua setup code)" do
        assert_equal 4, @error.line_number
      end

      should "have the Lua error message" do
        assert_equal "'=' expected near 'error'", @error.message
      end
    end

    context "from an included template" do
      setup do
        @error = Laminate::TemplateError.new \
          "eval:pcall : 'included: 'partial': [string \'local _out = {}; function out(s) table.insert(_out, tostring(s)...\']:7: '=' expected near 'partial_error'' (2)",
          'root.lam',
          [[:text, 'line 1\n'], [:code, " include('partial')"]]
      end

      should "be flagged included?" do
        assert @error.included_template?
      end

      should "have a template name" do
        assert_equal "partial", @error.template_name
      end

      should "have a line number for the error (NOT offset with the Lua setup code)" do
        assert_equal 7, @error.line_number
      end

      should "have the Lua error message" do
        assert_equal "'=' expected near 'partial_error'", @error.message
      end
    end
  end

  def html_sample
    <<-HTML
<div class='error'>
<h1>Error in template <em>root.lam</em> on line 4</h1>
<div class='message'>'=' expected near 'error'</div>
</div>
HTML
  end
end
