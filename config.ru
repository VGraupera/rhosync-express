require 'rubygems'
require 'sinatra'

root_dir = File.dirname(__FILE__)

disable :run

set :environment, ENV['RACK_ENV'].to_sym
set :raise_errors, true
set :views, File.dirname(__FILE__) + '/views'
set :public, File.dirname(__FILE__) + '/public'
set :root,        root_dir
set :app_file,    File.join(root_dir, 'rhosync.rb')

log = File.new("log/sinatra.log", "a")
$stdout.reopen(log)
$stderr.reopen(log)

require 'rhosync.rb'
run Sinatra::Application