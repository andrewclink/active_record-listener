$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require "bundler/setup"
require "active_record/listener"
# require 'database_cleaner'


# Configure Rails Environment
require 'active_record'
ENV['RAILS_ENV'] = 'test'
require 'active_record/connection_adapters/postgresql_adapter'
ENV['DATABASE_URL'] ||= 'postgresql://localhost/arl_test'
require File.expand_path('../../spec/dummy/config/environment.rb', __FILE__)


RSpec.configure do |config|
  
  config.disable_monkey_patching!
  
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  
  # config.before(:suite) do
  #   DatabaseCleaner.strategy = :drop
  #   DatabaseCleaner.clean_with(:truncation)
  # end
  #
  # config.around(:each) do |example|
  #   DatabaseCleaner.cleaning do
  #     example.run
  #   end
  # end
  
  config.befure(:suite) do
    ActiveRecord::Listener.listeners.each do |ch, listener|
      puts "Notice: ARL listening on #{ch}".colorize(:yellow)
    end
  end
  
  config.after(:suite) do
    ActiveRecord::Listener.listeners.each do |ch, listener|
      puts "Unlisten: #{ch}"
      listener.unlisten
    end
    
    Rails.application.load_tasks
    Rake::Task['db:drop'].invoke
    
  end
end

