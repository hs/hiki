#!/usr/bin/env ruby
hiki=''
eval( open( '../hikifarm.conf' ){|f|f.read.untaint} )
$:.unshift "#{hiki}"
load "#{hiki}/attach.cgi"
