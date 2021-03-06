require File.dirname(__FILE__) + '/../../test_helper'
require 'hpricot'

module Redmine
  class RDFormattingTest < Test::Unit::TestCase
    def test_format
      html = RDFormatting.to_html(<<-SOURCE.gsub(/\A( *)/, '').gsub(/^#{$1}/, ''))
        =begin
        = test
        (({def t; end}))
         test
        =end
      SOURCE
      doc = Hpricot.parse(StringIO.new(html))
      assert_not_nil doc/:h1
      assert_equal 'test', (doc/:h1).text
      assert_equal 'def t; end', (doc/:p/:code).text
      assert_equal 'test', (doc/:pre).text
    end
  end
end
