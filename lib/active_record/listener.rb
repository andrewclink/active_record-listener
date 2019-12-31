# frozen_string_literal: true

require "active_record/listener/version"

require_relative 'listener/base'
require_relative 'listener/state_monitor'

module ActiveRecord
  module Listener
    class Error < StandardError; end
    
    @listeners = {}
    @state_monitor = StateMonitor.instance

    def self.listeners
      @listeners
    end
  
    def self.listen(channel, &block)
      puts "ActiveRecord::Listener.listen(#{channel.inspect})".colorize(:light_blue)
      
      @state_monitor.when_connected do
        @listeners[channel] = Base.new.tap do |listener|
          listener.listen(channel, &block)
        end
      end
    end
  end
end
