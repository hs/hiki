require 'hiki/repos/default'
require 'English'

# Git Repository Backend for hikifarm
module Hiki
  class HikifarmReposGitfarm < HikifarmReposBase
    def imported?(wiki)
      s = ''
      Dir.chdir(@data_root) do
        open("|git ls-files -o --directory #{wiki}/text") do |f|
          s << (f.gets( nil ).chomp ? $_ : '')
        end
        ! s.empty?
      end
    end

    def import(wiki)
      Dir.chdir("#{@data_root}") do
        system("git add -- #{wiki}/text")
        system("git add -- #{wiki}/info.db > /dev/null 2>&1")
        system("git commit -q -m \"Starting #{wiki} from #{ENV['REMOTE_ADDR']}\" > /dev/null 2>&1".untaint)
      end
    end

    def update(wiki)
      Dir.chdir("#{@data_root}") do
        system("git add -- #{wiki}/text > /dev/null 2>&1")
        system("git add -- #{wiki}/info.db > /dev/null 2>&1")
        system("git commit -q -m \"Upadte #{wiki} from #{ENV['REMOTE_ADDR']}\" > /dev/null 2>&1".untaint)
      end
    end
  end

  class ReposGitfarm < ReposBase
    include Hiki::Util

    def initialize(root, data_path)
      super
      @data_root = File.dirname(data_path)
      @wiki_name = File.basename(data_path)
      @text_dir = File.join(@wiki_name, "text")
    end

    def commit(page, msg = default_msg)
      escaped_page = File.join(@text_dir, escape(page).untaint)
      Dir.chdir(@data_root) do
        system("git add -- #{escaped_page} > /dev/null 2>&1")
        system("git add -- #{@wiki_name}/info.db > /dev/null 2>&1")
        # titleのみ変更した場合に、"nothing to commit, ..." が返される
        system("git commit -q -m \"commit #{escaped_page}: #{msg.untaint}\" > /dev/null 2>&1")
      end
    end

    def commit_with_content(page, content, message = default_msg)
      escaped_page = escape(page).untaint
      Dir.chdir(@data_root) do
        File.open(File.join(@text_dir, escaped_page), "w+") do |file|
          file.write(content)
        end
      end
      commit(page)
    end

    def delete(page, msg = default_msg)
      escaped_page = File.join(@text_dir, escape(page).untaint)
      Dir.chdir(@data_root) do
        system("git rm -- #{escaped_page} > /dev/null 2>&1")
        system("git add -- #{@wiki_name}/info.db > /dev/null 2>&1")
        system("git commit -q -m \"delete #{escaped_page}: #{msg.untaint}\" > /dev/null 2>&1")
      end
    end

    def rename(old_page, new_page)
      old_page = File.join(@text_dir, escape(old_page.untaint))
      new_page = File.join(@text_dir, escape(new_page.untaint))
      Dir.chdir(@data_root) do
        raise ArgumentError, "#{new_page} has already existed." if File.exist?(new_page)
        system("git mv -- #{old_page} #{new_page} > /dev/null 2>&1")
        system("git add -- #{@wiki_name}/info.db > /dev/null 2>&1")
        system("git commit -q -m 'Rename #{old_page} to #{new_page}' > /dev/null 2>&1")
      end
    end

    def get_revision(page, revision)
      ret = ''
      escaped_page = File.join(@text_dir, escape(page).untaint)
      Dir.chdir(@data_root) do
        open("|git show #{revision}:#{escaped_page}".untaint) do |f|
          ret = f.read
        end
      end
      ret
    end

    def revisions(page)
      require 'time'
      all_log = ''
      git_logfmt="%h\t%ad\t%s"
      revs = []
      escaped_page = File.join(@text_dir, escape(page).untaint)
      Dir.chdir(@data_root) do
        open("|git log --date=iso --pretty=format:'#{git_logfmt}' --  -- #{escaped_page}") do |f|
          f.each_line do |line|
            hash,date,subject = line.chomp.split(/\t/)
            revs << [hash, date, '', subject]
          end
        end
      end
      revs
    end
  end
end
