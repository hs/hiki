#!/usr/bin/env ruby
# Copyright (C) 2003 TAKEUCHI Hitoshi <hitoshi@namaraii.com>

BEGIN { $stdout.binmode }

$SAFE     = 1

if FileTest.symlink?( __FILE__.untaint ) then
  org_path = File.dirname( File.expand_path( File.readlink( __FILE__.untaint ) ) )
else
  org_path = File.dirname( File.expand_path( __FILE__.untaint ) )
end
$:.unshift( org_path.untaint, "#{org_path.untaint}/hiki" )
$:.delete(".") if File.writable?(".")

require 'cgi'
require 'hiki/config'
require 'hiki/util'

include Hiki::Util

def redirect(cgi, url)
  body = %Q[
           <html>
           <head>
           <meta http-equiv="refresh" content="0;url=#{url}">
           <title>moving...</title>
           </head>
           <body>Wait or <a href="#{url}">Click here!</a></body>
           </html>]
  print cgi.header( 'type' => 'text/html' )
  puts body
end

def attach_file
  @conf = Hiki::Config.new
  set_conf(@conf)
  cgi = CGI.new

  params     = cgi.params
  page       = params['p'].first ? params['p'].first.read : 'FrontPage'
  command = params['command'].first ? params['command'].first.read : 'view'
  command = 'view' unless ['view', 'edit'].index(command)
  r = ''

  max_size = @conf.options['attach_size'] || 1048576

  if cgi.params['attach'].first
    begin
      raise 'Invalid request.' unless params['p'].first && params['attach_file'].first

      filename   = File.basename(params['attach_file'].first.original_filename.gsub(/\\/, '/'))
      cache_path = "#{@conf.cache_path}/attach"

      Dir.mkdir(cache_path) unless test(?e, cache_path.untaint)
      attach_path = "#{cache_path}/#{escape(page)}"
      Dir.mkdir(attach_path) unless test(?e, attach_path.untaint)
      path = "#{attach_path}/#{escape(filename.to_euc)}"
      if params['attach_file'].first.size > max_size
        raise "File size is larger than limit (#{max_size} bytes)."
      end
      unless filename.empty?
        content = params['attach_file'].first.read
        if (!@conf.options['attach.allow_script']) && (/<script\b/i =~ content)
          raise "You cannot attach a file that contains scripts."
        else
          open(path.untaint, "wb") do |f|
            f.print content
          end
          r << "FILE        = #{File.basename(path)}\n"
          r << "SIZE        = #{File.size(path)} bytes\n"
          send_updating_mail(page, 'attach', r) if @conf.mail_on_update
        end
      end
      redirect(cgi, "#{@conf.index_url}?c=#{command}&p=#{escape(page)}")
    rescue Exception => ex
      print cgi.header( 'type' => 'text/plain' )
      puts ex.message
    end
  elsif cgi.params['detach'].first then
    attach_path = "#{@conf.cache_path}/attach/#{escape(page)}"

    begin
      Dir.foreach(attach_path) do |file|
        next unless params["file_#{file}"].first
        path = "#{attach_path}/#{file}"
        if FileTest.file?(path.untaint) and params["file_#{file}"].first.read
          File.unlink(path)
          r << "FILE        = #{File.basename(path)}\n"
        end
      end
      Dir.rmdir(attach_path) if Dir.entries(attach_path).size == 2
      send_updating_mail(page, 'detach', r) if @conf.mail_on_update
      redirect(cgi, "#{@conf.index_url}?c=#{command}&p=#{escape(page)}")
    rescue Exception => ex
      print cgi.header( 'type' => 'text/plain' )
      puts ex.message
    end
  end
end

attach_file
