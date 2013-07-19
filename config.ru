require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require './video_store'

set :environment, :development
set :run, false
set :raise_errors, true

run Sinatra::Application
