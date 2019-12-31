module ActiveRecord
  module Listener
    class StateMonitor
      include Singleton
      
      @has_connection = false
      
      def initialize
        puts "ARL State Monitor waiting".colorize(:yellow)
        @waiting_blocks = []
        
        wait_for_connection
      end
      
      def has_connection?
        @has_connection
      end
      
      def when_connected(&block)
        if has_connection?
          puts "#{self.class}#when_connected - already connected; running block".colorize(:red)
          block.call
        else
          puts "#{self.class}#when_connected - queuing block".colorize(:red)
          @waiting_blocks << block
        end
      end
      
      def did_connect
        puts "#{self.class}#did_connect".colorize(:red)
        
        @has_connection = true
        while @waiting_blocks.count > 0
          callback = @waiting_blocks.shift
          puts "#{self.class}#did_connect - running block #{block.inspect}".colorize(:red)
          callback.call
        end
      end
      
      def wait_for_connection
        puts "#{self.class}#wait_for_connection".colorize(:red)

        ActiveSupport.on_load(:active_record) do

          puts "#{self.class} on_load(:active_record)".colorize(:red)
          
          subscription = ActiveSupport::Notifications.subscribe('!connection.active_record') do
            # Called in the context of self == ActiveRecord::Base
            #
            puts "#{self.class} ActiveRecord got connection".colorize(:green)
            
            begin
              # Time to notify classes that were made before now.
              ActiveRecord::Listener::StateMonitor.instance.did_connect
            ensure
              ActiveSupport::Notifications.unsubscribe(subscription)
            end
          end
        end
      end

    end
  end
end
