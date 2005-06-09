# $Id: test_default_parser.rb,v 1.4 2005-06-08 05:12:44 fdiary Exp $

require 'test/unit'
require 'style/default/parser'

class Default_Parser_Unit_Tests < Test::Unit::TestCase

  Config = Struct.new( :use_plugin )

  def setup
    conf = Config.new( true )
    @parser = Hiki::Parser_default.new( conf )
  end

  def test_heading
    assert_equal([{:lv=>1, :e=>:heading1_open},
                   {:s=>"h1", :e=>:normal_text},
                   {:lv=>1, :e=>:heading1_close}],
                 @parser.parse( "!h1" ) )
    assert_equal([{:lv=>5, :e=>:heading5_open},
                   {:s=>"h5", :e=>:normal_text},
                   {:lv=>5, :e=>:heading5_close}],
                 @parser.parse( "!!!!!h5" ) )
    assert_equal([{:lv=>5, :e=>:heading5_open},
                   {:s=>"!ng", :e=>:normal_text},
                   {:lv=>5, :e=>:heading5_close}],
                 @parser.parse( "!!!!!!ng" ) )
  end

  def test_def_list
    assert_equal([{:e=>:definition_list_open},
                   {:e=>:definition_term_open},
                   {:s=>"hoge", :e=>:normal_text},
                   {:e=>:definition_term_close},
                   {:e=>:definition_desc_open},
                   {:s=>"fuga", :e=>:normal_text},
                   {:e=>:definition_desc_close},
                   {:e=>:definition_desc_open},
                   {:s=>"geho", :e=>:normal_text},
                   {:e=>:definition_desc_close},
                   {:e=>:definition_list_close}],
                 @parser.parse( ":hoge:fuga\n::geho" ) )
  end

  def test_def_list_wikiname
    assert_equal([{:e=>:definition_list_open},
                   {:e=>:definition_term_open},
                   {:s=>"HoGe", :e=>:wikiname, :href=>"HoGe"},
                   {:e=>:definition_term_close},
                   {:e=>:definition_desc_open},
                   {:s=>"fuga", :e=>:normal_text},
                   {:e=>:definition_desc_close},
                   {:e=>:definition_desc_open},
                   {:s=>"geho", :e=>:normal_text},
                   {:e=>:definition_desc_close},
                   {:e=>:definition_list_close}],
                 @parser.parse( ":HoGe:fuga\n::geho" ) )
  end

  def test_inline_plugin
    assert_equal([{:e=>:p_open},
                   {:s=>"a", :e=>:normal_text},
                   {:method=>"hoge", :e=>:inline_plugin},
                   {:s=>"b", :e=>:normal_text},
                   {:e=>:p_close}],
                 @parser.parse( "a{{hoge}}b" ) )
  end

  def test_inline_plugin2
    assert_equal([{:e=>:p_open},
                   {:method=>"hoge", :e=>:inline_plugin},
                   {:s=>"a", :e=>:normal_text},
                   {:e=>:p_close}],
                 @parser.parse( "{{hoge}}a" ) )
  end

  def test_block_plugin
    assert_equal([{:method=>"hoge", :e=>:plugin}],
                 @parser.parse( "{{hoge}}" ) )
  end

  def test_block_plugin2
    assert_equal([{:method=>"hoge('123\n456')", :e=>:plugin}],
                 @parser.parse( "{{hoge('123\n456')}}\n" ) )
  end

  def test_link
    assert_equal([{:e=>:p_open},
		   {:s=>"str", :e=>:reference, :href=>"../data/"},
		   {:e=>:p_close}],
		 @parser.parse( "[[str|:../data/]]" ) )
    assert_equal([{:e=>:p_open},
		   {:s=>"../data/", :e=>:reference, :href=>"../data/"},
		   {:e=>:p_close}],
		 @parser.parse( "[[:../data/]]" ) )
  end

  def test_normalize_line
    assert_equal([{:e=>:p_open},
                   {:s=>"'''", :e=>:normal_text},
                   {:s=>"hoge", :e=>:normal_text},
                   {:e=>:p_close}],
                 @parser.parse( "'''hoge" ) )
  end
end