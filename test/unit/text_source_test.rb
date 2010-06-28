require 'test_helper'

class TextSourceTest < ActiveSupport::TestCase

  # --------------------------------------------------------------------------------
  # String function
  # --------------------------------------------------------------------------------

  def test_doublons
    assert_equal ".x.....", remove_doublon(".xx.....", "x")
    assert_equal ".x.....", remove_doublon(".xxx.....", "x")
    assert_equal ".x.....", remove_doublon(".x.....", "x")
    assert_equal ".@.....", remove_doublon(".xx.....", "x", "@")
    assert_equal ".@.....", remove_doublon(".xxx.....", "x", "@")
    assert_equal ".@..@..", remove_doublon(".xxx..ukuk..", ["x", "uk"], "@")
  end

  def test_remove_html_tags
    assert_equal "truc", remove_all_html_tags("<p>truc</p>")
    assert_equal "truc", remove_all_html_tags("<p a='titi'>  truc </p>")
  end

  # helpers....................

  def remove_doublon(s, x1, x2=nil)
    s.remove_doublons!(x1,x2)
    s
  end

  def remove_all_html_tags(s)
    s.remove_all_html_tags!
    s
  end


  # --------------------------------------------------------------------------------
  # TextSource
  # --------------------------------------------------------------------------------

  def test_normalized_review
    assert_equal build_example, TextSource.new("#{@sep}#{@p0}#{@sep}#{@p1}#{@sep}#{@p2}#{@sep}#{@sep}#{@p3}#{@sep}", :source => :text).content_normalized
    assert_equal build_example, TextSource.new("#{@p0}#{@sep}#{@p1}#{@sep}#{@sep}#{@p2}#{@sep}#{@sep}#{@p3}#{@sep}", :source => :text).content_normalized

    assert_equal build_example, TextSource.new("<p>#{@p0}</p><p>#{@p1}</p><p>#{@p2}</p><p>#{@p3}</p>", :source => :html).content_normalized
    assert_equal build_example, TextSource.new(" <p>#{@p0}#{@sep}</p>#{@sep}<p>#{@p1}</p>\r<p>#{@p2}\n</p>\r\n<p>#{@p3}</p>\t", :source => :html).content_normalized
  end

  def test_normalized_review_paragraphs
    build_example
    text_source = TextSource.new(" <p>#{@p0}#{@sep}</p>#{@sep}<p>#{@p1}</p>\r<p>#{@p2}\n</p>\r\n<p>#{@p3}</p>\t", :source => :html)

    assert_equal 4 , text_source.text_paragraphs.size
    assert_equal [@p0, @p1, @p2, @p3], text_source.text_paragraphs.collect(&:to_s)

  end

  # helpers....................

  def build_example
    @sep = "\n"
    [@p0 = "title",
    @p1 = "paragraph 1",
    @p2 = "paragraph 2",
    @p3 = "conclusion"].join(@sep)
  end

end
