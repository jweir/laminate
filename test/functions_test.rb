require File.expand_path(File.dirname(__FILE__) + '/helper')
require 'laminate'
require 'laminate/timeouts'

module TestFuncs
  def my_value
    42
  end

  def divider(v1, v2)
    v1  /  v2
  end

  def favorite_tv(a, b, c)
    a ||= "Daily Show"
    b ||= "Colbert"
    c ||= "South Park"
    "#{a}, #{b}, #{c}"
  end

  def check_types(abool, astring, anumber, ahash, anarray, nested_hash, nested2)
    errors = []

    [[abool, TrueClass], [astring, String], [anumber, Float], [ahash.to_h, Hash], [anarray.to_a, Array]].each do |comp|
      errors << "#{comp[0].class} is not a #{comp[1]}" if !comp[0].is_a?(comp[1])
    end

    "types #{errors.length > 0 ? errors.join("; ") : "OK"}"
  end

  def get_now
    Time.now
  end

  def get_today
    Time.now
  end
end

class Mysecrets
  def initialize
    @secret = 42
  end

  def is_this_it(compare)
    compare == @secret ? "Yes!" : "No..."
  end
end

class NestedFunctionsHelper < Laminate::AbstractLuaHelper
  namespace 'vodspot', 'vodspot.collections'
  # The 'post_process' call can indicate another Lua function which will process Ruby results before they are returned to the template caller.
  # See the test below that defines the 'getdouble' Lua function.
  post_process :get42, :vodspot_get42, :with => 'getdouble'
  post_process :vodspot_colors, :with => 'annotate_table'
  post_process :search, :with => '_rb_post_process'

  def vodspot_videos
    "list of vodspot videos"
  end

  # Matches prefix, and method includes a '_'
  def vodspot_video_id
    99
  end

  # Matches prefix but doesn't have the separator - should bind to top level
  def vodspottop_level
    "topper"
  end

  def toplevel
    "non-nested function"
  end

  def vodspot_collections_first
    "first vodspot collection"
  end

  def get42
    42
  end

  def vodspot_get42
    42
  end

  def vodspot_colors
    {:results => ['red','green','blue','orange'], :total_colors => 100}
  end

  def search
    {'search_results' => ['result 1', 'result 2', 'result 3'], 'page' => 1, 'total' => 100}
  end
end


class FunctionsTest < Test::Unit::TestCase

  test "auto conversion of Date and Time" do
    template = "The current Time in seconds equals: <%= get_now() %> and today in seconds equals: <%= get_today() %>"
    lam = Laminate::Template.new(:text => template)

    now = Time.now
    res = lam.render(:helpers => [TestFuncs])

    assert res =~ /seconds equals: #{now.to_i}/
  end

  test "debug_all" do
    lam = Laminate::Template.new(:text => "Debug info:\n <%= debug_all() %>")
    res = lam.render(:locals => {:name => 'Ron Burgundy', :colors => ['gold', 'purple']}, :helpers => [TestFuncs, Mysecrets.new])

    assert res =~ /name.*Ron Burgundy/
    assert res =~ /colors.*purple/
    assert res =~ /TestFuncs.*divider/
    assert res =~ /Mysecrets.*is_this_it/
  end


  test "debug function" do
    lam = Laminate::Template.new(:text => "your profile:\n<%= debug(profile)%>\ncolor: <%= debug(color) %>")

    res = lam.render(:locals => {:color => 'blue', :profile => {:name => 'Chazz Rheinhold', :age => 39}})
    assert res =~ /name.*Chaz/
    assert res =~ /age.*39/
    assert res =~ /color: blue/
  end

   # Look at NestedFunctionsHelper above to see how to indicate that a Lua function should process Ruby results
   # before returning them to the Laminate caller.
   test "post processing" do
     lua =<<-ENDLUA
     <% function getdouble(i) return i*2; end %>
     <%= get42() %> = 84
     Nested <%= vodspot.get42() %> --> 84
     ENDLUA

     lam = Laminate::Template.new(:text => lua)

     res = lam.render(:helpers => [NestedFunctionsHelper.new])
     assert res =~ /84 = 84/
     assert res =~ /Nested 84 --> 84/

     # Test table annotation (attaching attributes to a Lua array). This is especially useful for annotating an
     # array with a "total" attribute. This is easy in Lua. Laminate includes a built-in "_rb_post_process" function
     # which can do this for you. Just have your Ruby function return any hash containing one array and 1 or more
     # scalars.
     lua =<<-ENDLUA
     <% function annotate_table(tuple) res = tuple.results; res.total_colors = tuple.total_colors; return res; end %>
     <% colors = vodspot.colors() %>
     Got <%= #colors %> out of <%= colors.total_colors %> total
     <% search_results = search() %>
     Search returned <% for i,v in ipairs(search_results) do out(v .. ','); end %> from page <%= search_results.page %> of <%= search_results.total %>
     ENDLUA

     lam = Laminate::Template.new(:text => lua)

     res = lam.render(:helpers => [NestedFunctionsHelper.new])
     assert res =~ /Got 4 out of 100 total/
     assert res =~ /Search returned result 1,result 2,result 3, from page 1 of 100/
   end
end

