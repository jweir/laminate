require File.expand_path(File.dirname(__FILE__) + '/helper')
require 'logger'
require 'laminate'
require 'shoulda'
require 'laminate/timeouts'

class TemplateTest < Test::Unit::TestCase
  include Laminate

  context "vendor_lua" do
    setup do
      @lam = Laminate::Template.new(
          :text => "Hello {{vendor.world()}}, today is {{ text }}",
          :vendor_lua => "vendor = {world=function() return 'World'; end }"
          )
    end

    should "allow injecting additional functions and properties" do
      assert_equal "Hello World, today is great", @lam.render(:locals => {:text => "great"}).strip
    end

  end

end