# TODO increase the coverage of the test, many Loader methods are not covered
require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'logger'
require 'laminate'
require 'laminate/timeouts'

class Laminate::Loader::Test < Test::Unit::TestCase

  context "Laminate::Loader" do
    setup do
      mock_file :expects, "/template.lam", "code"
      @loader = Laminate::Loader.new "/"
    end

    should "return the template source" do
      assert_equal "code", @loader.load_template("template")
    end
  end

  context "Laminate::InlineLoader" do
    setup do
      @loader = Laminate::InlineLoader.new "code"
    end

    should "return the template source" do
      assert_equal "code", @loader.load_template
    end
  end


end
