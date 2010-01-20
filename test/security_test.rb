require File.expand_path(File.dirname(__FILE__) + '/helper')
require 'logger'
require 'laminate'
require 'laminate/timeouts'


class SecurityTest < Test::Unit::TestCase
  def setup
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::FATAL
  end
  
  def should_raise_error(code)
    assert_raise Laminate::TemplateError, "#{code} should have raised an error" do
       Laminate::Template.new(:text => code, :logger => @logger).render(:raise_errors => true)
    end
  end
  
  test "laminate_excludes_lua_builtin_funcs" do
    should_raise_error "{{ assert(loadstring('x = 1'))() }}"
    should_raise_error "{{ package.path }}"
    should_raise_error "{{ os.clock() }}"
    should_raise_error "{{ os.execute('ls') }}"
    should_raise_error "{{ io.stdout:write('hello world') }}"
    should_raise_error "{{ require ('io') }}"
    should_raise_error "{{ dofile('fixtures/snippet.lua') }}"
    should_raise_error "{{ collectgarbage('stop') }}"
    should_raise_error "{{ x = #_G }}"
    should_raise_error "{{ x = getfenv(0) }}"
    should_raise_error "{{ y = getmetatable('') }}"
    should_raise_error "{{ setfenv(1, {}) }}"
    should_raise_error "{{ setmetatable(string, {}) }}"
    should_raise_error "{{ assert(loadfile('barx.lua'))}}"
    # We disable string:rep because it can use too much memory
    should_raise_error "{{ if string.rep(' ', 3) ~= '   ' then error('overridde'); end }}"

  end

  test "the timeout should abort a long running template" do
    # If this test does not break after 20 secs then Lua timeouts are NOT working properly
    start = Time.now
    assert_raise Laminate::TemplateError do
      Laminate::Template.new(:text => "{{ for i=1,1e12 do f = 'hello'; end }}", :logger => @logger).render(:raise_errors => true, :timeout => 5)
    end
    assert_in_delta 5.0, (Time.now - start), 0.1
  end
  
  test "calling the alarm should cancel the template immediately" do
    # Attach the alarm function
    start = Time.now
    assert_raise Laminate::TemplateError do
      Laminate::Template.new(:text => "{{ alarm(0) }} {{ for i=1,1e12 do f = 'hello'; end }}", :logger => @logger).render(:raise_errors => true, :timeout => 5)
    end
    assert_in_delta 0.0, (Time.now - start), 0.1

  end

  test "print function redefined as template output" do
    #res = Laminate::Template.new(:text => "{{ print('hello world') }} and {{ ',and goodbye' }}").render
    #puts res
    #assert res =~ /hello world,and goodbye/
  end

end

