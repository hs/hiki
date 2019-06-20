require "hiki/repository/base"
require 'English'

# Git Repository Backend for hikifarm
module Hiki
  module FarmRepository
    class Gitfarm < Base

      FarmRepository.register(:gitfarm, self)

      def initialize(repos_root, data_path)
        super
        git_opt = @repos_root.to_s.empty? ? '' : "--separate-git-dir=#{@repos_root}"

        unless FileTest.exist?("#{@data_path}/.git") && (@repos_root.to_s.empty? || FileTest.directory?(@repos_root))
          require 'fileutils'
          Dir.chdir(@data_path) do
            unless system("git init #{git_opt} > /dev/null 2>&1")
              require 'fileutils'
              FileUtils.rm('.git', {force: true}) if FileTest.exist?('.git')
              raise "git init[#{@repos_root}] failed."
            end
            File.open('.gitignore', "w+") do |file|
              file.print <<~EOF
                info.db
                cache
                session
                backup
                hiki.conf
                .gitignore
              EOF
            end
            Dir["*"].each do |wiki|
              next unless wiki.match(/\A[0-9a-z]+\z/)
              wiki.untaint
              import(wiki) if FileTest.directory?("#{wiki}/text") && FileTest.exist?("#{wiki}/info.db")
            end
          end
        end
      end

      def imported?(wiki)
        s = ''
        Dir.chdir(@data_path) do
          open("|git ls-files -o --directory #{wiki}/text") do |f|
            s << (f.gets( nil ).chomp ? $_ : '')
          end
          ! s.empty?
        end
      end

      def import(wiki)
        Dir.chdir("#{@data_path}") do
          system("git add -- #{wiki}/text")
          system("git add -- #{wiki}/info.db > /dev/null 2>&1")
          system("git commit -q -m \"Starting #{wiki} from #{ENV['REMOTE_ADDR']}\" > /dev/null 2>&1".untaint)
        end
      end

      def update(wiki)
        Dir.chdir("#{@data_path}") do
          system("git add -- #{wiki}/text > /dev/null 2>&1")
          system("git add -- #{wiki}/info.db > /dev/null 2>&1")
          system("git commit -q -m \"Upadte #{wiki} from #{ENV['REMOTE_ADDR']}\" > /dev/null 2>&1".untaint)
        end
      end

      def destroy(wiki)
        Dir.chdir("#{@data_path}") do
          system("git rm -r -- #{wiki} > /dev/null 2>&1")
          system("git commit -q -m \"Destroy #{wiki} from #{ENV['REMOTE_ADDR']}\" > /dev/null 2>&1".untaint)
        end
      end
    end
  end

  module Repository
    class Gitfarm < Base
      include Hiki::Util

      Repository.register(:gitfarm, self)

      def initialize(root, data_path)
        super
        @data_path = data_path
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
end
