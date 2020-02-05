# frozen_string_literal: true

require "active_record/listener/version"

require_relative 'listener/base'
require_relative 'listener/state_monitor'

module ActiveRecord
  module Listener
    class Error < StandardError; end
    
    @state_monitor = StateMonitor.instance

    def self.listen(channel, &block)
      @state_monitor.when_connected do
        
        disconnect_all and return if in_rake_task?
        
        Base.new.tap do |listener|
          listener.listen(channel, &block)
        end
      end
    end

    def self.notify(channel, payload)
      ActiveRecord::Base.connection_pool.with_connection do |ar_conn|
        ar_conn.raw_connection.tap do |pg_conn|
          pg_conn.exec("NOTIFY #{pg_conn.escape_identifier(channel)}, '#{pg_conn.escape_string(payload)}'")
        end
      end
    end
    
    def self.disconnect_all
      puts "ARL: disconnect_all".colorize(:yellow)
      notify('arl_disconnect_hook', 'disconnect')
    end
    
    def self.in_rake_task?
      if ARGV[0] =~ /\:|db/
        true
      else
        false
      end
    end
    
  end
end
