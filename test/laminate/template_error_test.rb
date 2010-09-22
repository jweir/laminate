require File.expand_path(File.dirname(__FILE__) + '/../helper')
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

    # should "laminate_compile_errors" do
      # template = "<h1>heading</h1><%color%><% System.exit%>"
      # lam = Laminate::Template.new(:text => template, :logger => @logger)

      # assert !lam.compile
      # assert lam.errors.size > 0

      # lam.render

      # assert_raise Laminate::TemplateError do
        # lam.render!
      # end

      # template =<<-ENDTEMP
        # <html>
        # <body>
          # <h1>Heading<\/h1>
          # {{loop error}}
        # <\/body>
        # <\/html>
      # ENDTEMP

      # lam = Laminate::Template.new(:text => template, :logger => @logger)
      # res = lam.render
      # assert res =~ /Template.*error/i
    # end


    # should "unclosed_block_errors" do
      # Template has no {{end}} clause
      # template = "<h1>heading<\/h1>\n{{for i,video in ipairs(videos) do}}\n<p>\n{{video.title}}\n{{end}}<\/p>{{if true then}}\n<b>nice<\/b>"
      # lam = Laminate::Template.new(:text => template, :logger => @logger)

      # res = lam.render
      # assert (res =~ /expecting \{\{end\}\}/ || res =~ /'end' expected/)
    # end

    # should "lua_syntax_error" do
      # template = "heading\n{{if _}}\nloop line\n{{end}}"
      # lam = Laminate::Template.new(:text => template, :logger => @logger)

      # assert_raise Laminate::TemplateError do
        # lam.render!
      # end
    # end

    # should "include_error" do
      # lam = Laminate::Template.new(:file => File.dirname(__FILE__) + "/../fixtures/errortest.lam", :logger => @logger)
      # assert_match /error/i, lam.render, "Expected error in included template"
    # end


    # should "include runtime error" do
      # lam = Laminate::Template.new(:file => File.dirname(__FILE__) + "/../fixtures/errortest.lam", :logger => @logger)
      # assert_match /error/i, lam.render(:locals => {:error_file => '_badinclude2'}), "Expected error in included template"
    # end

    # should "ruby exception converted to TemplateError" do
      # template =<<-ENDTEMP
      # line1
      # line2
      # {{ func_raises_error() }}
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
      # {{ post_processed_func('foo', 'bar') }}
      # ENDLUA

      # lam = Laminate::Template.new(:text => lua, :logger => @logger)
      # assert_raise Laminate::TemplateError do
       # lam.render!(:helpers => [TestFuncs])
      # end

      # assert lam.render(:helpers => [TestFuncs])
    # end
  end
end

