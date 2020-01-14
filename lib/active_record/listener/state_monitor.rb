module ActiveRecord
  module Listener
    class StateMonitor
      include Singleton
      
      @has_connection = false
      
      def debug_log(msg)
      end
      
      def initialize
        debug_log "ARL State Monitor waiting".colorize(:yellow)
        @waiting_blocks = []
        
        wait_for_connection
      end
      
      def has_connection?
        @has_connection
      end
      
      def when_connected(&block)
        if has_connection?
          debug_log "#{self.class}#when_connected - already connected; running block".colorize(:red)
          block.call
        else
          debug_log "#{self.class}#when_connected - queuing block".colorize(:red)
          @waiting_blocks << block
        end
      end
      
      def did_connect
        debug_log "#{self.class}#did_connect".colorize(:red)
        
        @has_connection = true
        while @waiting_blocks.count > 0
          callback = @waiting_blocks.shift
          debug_log "#{self.class}#did_connect - running block #{block.inspect}".colorize(:red)
          callback.call
        end
      end
      
      def wait_for_connection
        debug_log "#{self.class}#wait_for_connection".colorize(:red)

        ActiveSupport.on_load(:active_record) do
          subscription = ActiveSupport::Notifications.subscribe('!connection.active_record') do
            # Called in the context of self == ActiveRecord::Base
            #
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
