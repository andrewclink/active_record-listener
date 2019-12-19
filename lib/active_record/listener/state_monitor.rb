module ActiveRecord
  module Listener
    class StateMonitor
      include Singleton
      
      @has_connections = false
      
      class << self
        def wait_for_connection
          puts "#{self.class}#wait_for_connection".colorize(:red)

          ActiveSupport.on_load(:active_record) do

            puts "#{self.class} on_load(:active_record)".colorize(:red)
            
            subscription = ActiveSupport::Notifications.subscribe('!connection.active_record') do

              puts "#{self.class} ActiveRecord got connection".colorize(:green)

              begin
                @has_connections = true
                # Time to notify classes that were made before now.
              ensure
                ActiveSupport::Notifications.unsubscribe(subscription)
              end
            end
          end
        end
      end

    end
  end
end
