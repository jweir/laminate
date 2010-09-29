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


  context "errors" do
    setup do
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::FATAL
    end

    context "Lua runtime error" do
      setup do
        lam = Laminate::Template.new(:text => "hello \n<% world() %>", :logger => @logger)
        @result = lam.render
      end

      should "raise an error" do
        assert_match /Template.*error/i, @result
      end
    end

    should "raise the error when render! is called" do
      template = "<h1>heading</h1><%color%><% System.exit%>"
      lam = Laminate::Template.new(:text => template, :logger => @logger)

      lam.render
      assert_raise Laminate::TemplateError do
        lam.render!
      end
    end

    should "show the error's line number" do

      template =<<-ENDTEMP
        <html>
        <body>
          <h1>Heading<\/h1>
          <% loop error %>
        <\/body>
        <\/html>
      ENDTEMP

      lam = Laminate::Template.new(:text => template, :logger => @logger)
      assert_match /Template.*error/i, lam.render
      assert_match /line 4/i, lam.render
    end


    should "raise an error fo unclosed blocks" do
      template = "<% if true then%> unclosed"
      lam = Laminate::Template.new(:text => template, :logger => @logger)

      assert_match /'end' expected/, lam.render
    end

    should "lua_syntax_error" do
      template = "<%if _%><%end%>"
      lam = Laminate::Template.new(:text => template, :logger => @logger)

      assert_raise Laminate::TemplateError do lam.render!  end
    end

    should "include the template name" do
      mock_file :expects, "/named_template.lam", "<%= bad syntax %>"
      assert_match 'named_template', Laminate::Template.new(:file => "/named_template", :logger => @logger).render
    end

    context "a bad include" do
      setup do
        mock_file :expects, "/template.lam", "<%= include('no_file') %>"
        File.expects(:exist?).with("/no_file.lam").returns false

        @result = Laminate::Template.new(:file => "/template", :logger => @logger).render
      end

      should "raise an error" do
        assert_match /error/i, @result
      end

      should "include the missing template name" do
        assert_match /no_file/i, @result
      end
    end


    # should "include runtime error" do
      # lam = Laminate::Template.new(:file => File.dirname(__FILE__) + "/../fixtures/errortest.lam", :logger => @logger)
      # assert_match /error/i, lam.render(:locals => {:error_file => '_badinclude2'}), "Expected error in included template"
    # end

    # should "ruby exception converted to TemplateError" do
      # template =<<-ENDTEMP
      # line1
      # line2
      # <% func_raises_error() %>
      # line 4
      # ENDTEMP
      # lam = Laminate::Template.new(:text => template, :logger => @logger)

      # assert_raise Laminate::TemplateError do
       # lam.render!(:helpers => [TestFuncs])
      # end

      # assert lam.render(:helpers => [TestFuncs]) =~ /error at line 3/i

      # Test without exception wrapping
      # assert_raise RuntimeError do
        # assert lam.render!(:helpers => [TestFuncs], :wrap_exceptions => false)
      # end

      # lua =<<-ENDLUA
      # line 1
      # line 2
      # line 3
      # <% post_processed_func('foo', 'bar') %>
      # ENDLUA

      # lam = Laminate::Template.new(:text => lua, :logger => @logger)
      # assert_raise Laminate::TemplateError do
       # lam.render!(:helpers => [TestFuncs])
      # end

      # assert lam.render(:helpers => [TestFuncs])
    # end
  end

def example

<<-TEXT
Heading
Text
<%include('_badinclude')%>
More TExt
<%loop(badvar)%>
  loop line
<%end%>
TEXT
end
end
