# -*- coding: utf-8 -*-

require 'test_helper'
require "hiki/repository/gitfarm"
require 'hiki/util'

class Repos_Gitfarm_Tests < Test::Unit::TestCase
  include Hiki::Util
  include TestHelper

  def setup
    # git command check
    check_command("git")
    @current_revision = git("log", "-n 1", "--format=%H")
    # 
    @wiki = 'wikiwiki'
    # 
    @tmp_dir = File.join(File.dirname(__FILE__), "tmp_gitfarm")
    @data_dir = "#{@tmp_dir}/data"
    @text_dir = "#{@data_dir}/#{@wiki}/text"
    @repos_root = "#{@tmp_dir}/git"
    # default pages
    @default_pages_path = "#{@data_dir}/text"
    FileUtils.mkdir_p(@default_pages_path)
    write('', "Foo", 'foo')
    write('', "Bar", 'bar')
    # test Farm
    @farm_pub_path = "#{@tmp_dir}/public"
    FileUtils.mkdir_p(@farm_pub_path)
    @farm = Hikifarm.new(@farm_pub_path, '/usr/bin/env ruby', :gitfarm, @repos_root, @data_dir)
    @repos = Hiki::Repository::Gitfarm.new(@repos_root, "#{@data_dir}/#{@wiki}")
    # test Wiki
    @farm.create_wiki(@wiki, '', 'index.cgi', nil, @data_dir, @default_pages_path)
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
    git("reset", "--soft", @current_revision)
  end

  def test_new_farm
    tmp_dir = File.join(File.dirname(__FILE__), "tmp_new_gitfarm")
    @data_dir = "#{tmp_dir}/data"
    FileUtils.mkdir_p(@data_dir)
    farm_pub_path = "#{tmp_dir}/public"
    FileUtils.mkdir_p(farm_pub_path)
    repos_root = "#{tmp_dir}/git"
    # prepare wiki
    wiki = 'tikitiki'
    FileUtils.mkdir_p("#{@data_dir}/#{wiki}/text")
    write(wiki, "Hoe", 'hoehoe')
    assert(FileTest.file?("#{@data_dir}/#{wiki}/text/Hoe"))
    FileUtils.touch("#{@data_dir}/#{wiki}/info.db")
    #
    farm = Hikifarm.new(farm_pub_path, '/usr/bin/env ruby', :gitfarm, repos_root, @data_dir)
    # repository
    assert(FileTest.directory?(repos_root))
    assert(File.exist?("#{repos_root}/HEAD"))
    Dir.chdir(@data_dir) do
      assert(FileTest.file?('.git'))
      assert_equal(File.open('.git').read.chomp, "gitdir: #{repos_root}")
      assert(File.exist?('.gitignore'))
      # existing wiki
      object = nil
      object = git("hash-object", "#{wiki}/text/Hoe")
      assert_false(object.nil?)
      assert_equal('hoehoe', git("cat-file", "blob", object))
    end
  ensure
    FileUtils.rm_rf(tmp_dir) if FileTest.directory?(tmp_dir)
  end

  def test_new_farm_without_repos_root
    tmp_dir = File.join(File.dirname(__FILE__), "tmp_new_gitfarm_without_repos_root")
    @data_dir = "#{tmp_dir}/data"
    FileUtils.mkdir_p(@data_dir)
    farm_pub_path = "#{tmp_dir}/public"
    FileUtils.mkdir_p(farm_pub_path)

    farm = Hikifarm.new(farm_pub_path, '/usr/bin/env ruby', :gitfarm, nil, @data_dir)
    Dir.chdir(@data_dir) do
      assert(FileTest.directory?('.git'))
      assert(File.exist?("#{@data_dir}/.git/HEAD"))
      assert(File.exist?('.gitignore'))
    end
  ensure
    FileUtils.rm_rf(tmp_dir) if FileTest.directory?(tmp_dir)
  end

  def test_new_wiki
    wiki = 'wikitiki'

    @farm.create_wiki(wiki, '', 'index.cgi', 'attach.cgi', @data_dir, @default_pages_path)
    # public directory and files
    assert(File.directory?("#{@farm_pub_path}/#{wiki}"))
    assert(File.exist?("#{@farm_pub_path}/#{wiki}/index.cgi"))
    assert(File.exist?("#{@farm_pub_path}/#{wiki}/attach.cgi"))
    assert(File.exist?("#{@farm_pub_path}/#{wiki}/hikiconf.rb"))

    # default pages copy
    assert(File.exist?("#{@data_dir}/#{wiki}/text/Foo"))
    assert(File.exist?("#{@data_dir}/#{wiki}/text/Bar"))
    assert_equal(read('', "Foo"), read(wiki, "Foo"))
    assert_equal(read('', "Bar"), read(wiki, "Bar"))
    object = nil
    Dir.chdir(@data_dir) do
      object = git("hash-object", "#{wiki}/text/Foo")
      assert_false(object.nil?)
      assert_equal(read('', "Foo"), git("cat-file", "blob", object))
      object = git("hash-object", "#{wiki}/text/Bar")
      assert_false(object.nil?)
      assert_equal(read('', "Bar"), git("cat-file", "blob", object))
    end

    # add new page
    repos = Hiki::Repository::Gitfarm.new(@repos_root, "#{@data_dir}/#{wiki}")
    write(wiki, "FooBar", 'foobar')
    repos.commit("FooBar")
    assert_equal('foobar', read(wiki, "FooBar"))
    object = nil
    Dir.chdir(@data_dir) do
      object = git("hash-object", "#{wiki}/text/FooBar")
      assert_false(object.nil?)
      assert_equal('foobar', git("cat-file", "blob", object))
    end
  end

  def test_commit
    write(@wiki, "FooBar", 'foobar')
    @repos.commit("FooBar")
    assert_equal('foobar', read(@wiki, "FooBar"))
    object = nil
    Dir.chdir(@data_dir) do
      object = git("hash-object", "#{@wiki}/text/FooBar")
    end

    write(@wiki, "FooBar", 'foobar new')
    @repos.commit("FooBar")
    assert_equal('foobar new', read(@wiki, "FooBar"))

    Dir.chdir(@data_dir) do
      assert_equal("foobar", git("cat-file", "blob", object))
    end
  end

  def test_commit_with_content
    @repos.commit_with_content("FooBar", "foobar")
    assert_equal("foobar", read(@wiki, "FooBar"))
    old_hash = nil
    Dir.chdir(@data_dir) do
      old_hash = git("hash-object", "#{@wiki}/text/FooBar")
    end
    @repos.commit_with_content("FooBar", "foobar new")
    assert_equal("foobar new", read(@wiki, "FooBar"))

    Dir.chdir(@data_dir) do
      assert_equal("foobar", git("cat-file", "blob", old_hash))
    end
  end

  def test_get_revision
    rev1 = rev2 = rev3 = nil
    write(@wiki, "HogeHoge", 'hogehoge1')
    Dir.chdir(@data_dir) {git("add", "#{@wiki}/text/HogeHoge")}
    Dir.chdir(@data_dir) {git("commit", "-m", "First", "#{@wiki}/text/HogeHoge")}
    Dir.chdir(@data_dir) {rev1 = git("log", "-1", "--oneline", "--", "#{@wiki}/text/HogeHoge")}
    write(@wiki, "HogeHoge", 'hogehoge2')
    Dir.chdir(@data_dir) {git("commit", "-m", "Second", "#{@wiki}/text/HogeHoge")}
    Dir.chdir(@data_dir) {rev2 = git("log", "-1", "--oneline", "--", "#{@wiki}/text/HogeHoge")}
    write(@wiki, "HogeHoge", 'hogehoge3')
    Dir.chdir(@data_dir) {git("commit", "-m", "Third", "#{@wiki}/text/HogeHoge")}
    Dir.chdir(@data_dir) {rev3 = git("log", "-1", "--oneline", "--", "#{@wiki}/text/HogeHoge")}

    assert_equal('hogehoge1', @repos.get_revision('HogeHoge', rev1[0, 7]))
    assert_equal('hogehoge2', @repos.get_revision('HogeHoge', rev2[0, 7]))
    assert_equal('hogehoge3', @repos.get_revision('HogeHoge', rev3[0, 7]))
  end

  def test_revisions
    rev1 = rev2 = rev3 = nil
    write(@wiki, "HogeHoge", 'hogehoge1')
    Dir.chdir(@text_dir) {git("add", "HogeHoge")}
    Dir.chdir(@text_dir) {git("commit", "-m", "First", "HogeHoge")}
    Dir.chdir(@text_dir) {rev1 = git("log", "-1", "--oneline", "--", "HogeHoge")}
    modified1 = Time.now.localtime.strftime('%Y/%m/%d %H:%M:%S')
    write(@wiki, "HogeHoge", 'hogehoge2')
    Dir.chdir(@text_dir) {git("commit", "-m", "Second", "HogeHoge")}
    Dir.chdir(@text_dir) {rev2 = git("log", "-1", "--oneline", "--", "HogeHoge")}
    modified2 = Time.now.localtime.strftime('%Y/%m/%d %H:%M:%S')
    write(@wiki, "HogeHoge", 'hogehoge3')
    Dir.chdir(@text_dir) {git("commit", "-m", "Third", "HogeHoge")}
    Dir.chdir(@text_dir) {rev3 = git("log", "-1", "--oneline", "--", "HogeHoge")}
    modified3 = Time.now.localtime.strftime('%Y/%m/%d %H:%M:%S')

    expected = [
                [rev3[0, 7], modified1, '', 'Third'],
                [rev2[0, 7], modified2, '', 'Second'],
                [rev1[0, 7], modified3, '', 'First'],
               ].transpose
    actual = @repos.revisions('HogeHoge').transpose

    assert_equal(expected[0], actual[0])
    # disable to fragile test
    # assert_equal(expected[1], actual[1])
    assert_equal(expected[2], actual[2])
    assert_equal(expected[3], actual[3])
  end

  def test_rename
    write(@wiki, "HogeHoge", "hogehoge1\n")
    @repos.commit("HogeHoge")
    @repos.rename("HogeHoge", "FooBar")
    assert_equal("hogehoge1\n", read(@wiki, "FooBar"))
  end

  def test_rename_multibyte
    write(@wiki, escape("ほげほげ"), "hogehoge1\n")
    @repos.commit("ほげほげ")
    @repos.rename("ほげほげ", "ふーばー")
    assert_equal("hogehoge1\n", read(@wiki, escape("ふーばー")))
  end

  def test_rename_new_page_already_exist
    write(@wiki, "HogeHoge", "hogehoge1\n")
    @repos.commit("HogeHoge")
    write(@wiki, "FooBar", "foobar\n")
    @repos.commit("FooBar")
    assert_raise(ArgumentError) do
      @repos.rename("HogeHoge", "FooBar")
    end
  end

  def test_pages
    write(@wiki, escape("ほげほげ"), "hogehoge1\n")
    @repos.commit("ほげほげ")
    write(@wiki, "FooBar", "foobar\n")
    @repos.commit("FooBar")

    expected = ["Foo", "Bar", "ほげほげ", "FooBar"]
    expected = expected.map{|v| v.force_encoding("binary") }

    assert_equal(expected.sort, @repos.pages.sort)
  end

  def test_pages_with_block
    write(@wiki, escape("ほげほげ"), "hogehoge1\n")
    @repos.commit("ほげほげ")
    write(@wiki, "FooBar", "foobar\n")
    @repos.commit("FooBar")

    actuals = []
    @repos.pages.each do |page|
      actuals << page
    end

    expected = ["Foo", "Bar", "ほげほげ", "FooBar"]
    expected = expected.map{|v| v.force_encoding("binary") }

    assert_equal(expected.sort, actuals.sort)
  end

  private
  def git(*args)
    args = args.collect{|arg| arg.dump}.join(' ')
    result = `git #{args}`.chomp
    raise result unless $?.success?
    result
  end

  def file_name(wiki, page)
    File.join(@data_dir, wiki, "text", page)
  end

  def write(wiki, page, content)
    File.open(file_name(wiki, page), "wb") do |f|
      f.print(content)
    end
  end

  def read(wiki, page)
    File.open(file_name(wiki, page), "rb") do |f|
      f.read
    end
  end
end
