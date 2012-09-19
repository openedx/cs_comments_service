require 'rubygems'
require 'bundler/setup'
require 'rspec'
require 'rspec-steps'
require 'capybara/rspec'
#require 'capybara/poltergeist'
require 'capybara-webkit'
require 'faker'
require './helpers'
require 'pry'

# Capybara configuration
#Capybara.default_driver = :poltergeist
Capybara.default_driver = :webkit
Capybara.javascript_driver = :webkit
Capybara.save_and_open_page_path = File.dirname(__FILE__) + '/../snapshots'
Capybara.app_host = 'http://localhost:8000'
