# TODO increase the coverage of the test, many Loader methods are not covered
require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require 'logger'
require 'laminate'
require 'laminate/timeouts'

class Laminate::Loader::Test < Test::Unit::TestCase

  context "Laminate::Loader" do
    setup do
      File.expects(:exist?).with("./template.lam").returns true
      File.expects(:open).with("./template.lam").returns mock(:read => "<%code%> text")
      @loader = Laminate::Loader.new "." 
    end

    should "parse the source when initialized" do
      assert_equal ['code', ' text'], @loader.load_template("template").map(&:last)
    end
  end

  context "Laminate::InlineLoader" do
    setup do
      @loader = Laminate::InlineLoader.new "<%code%> text"
    end

    should "parse the source when initialized" do
      assert_equal ['code', ' text'], @loader.load_template.map(&:last)
    end
  end


end
