# frozen_string_literal: true

module ActiveRecord
  module Listener
    class Base

      def initialize
        @listening = false
        @queue = []
      end

      def verify!(pg_conn)
        return if pg_conn.is_a?(PG::Connection)
        raise 'The Active Record database must be PostgreSQL in order to use LISTEN/NOTIFY with ActiveRecordListener'
      end

      def with_notify_connection
        puts 'ActiveRecord::Listener::Base: will checkout connection'.colorize(:light_blue)
        ar_conn = ActiveRecord::Base.connection_pool.checkout

        if ar_conn.nil?
          puts 'ActiveRecord::Listener::Base: could not get connection!'.colorize(:red)
          return
        end

        # ActiveRecord::Listener is taking ownership over this database connection, and
        # will perform the necessary cleanup tasks
        ActiveRecord::Base.connection_pool.remove(ar_conn)

        pg_conn = ar_conn.raw_connection
        verify! pg_conn

        yield pg_conn
      rescue PG::ConnectionBad
        # Let's not be the bearer of bad news. Specifically, let's not cause 
        # rake db:create to fail because the database doesn't yet exist
        puts "#{self.class}: Received PG::ConnectionBad. Ignoring (and not listening)".colorize(:yellow)
      ensure
        ar_conn.disconnect! unless ar_conn.nil?
      end

      public

      # This runs on the listener thread
      def threaded(&block)
        @thread = Thread.new do
          Thread.current.name = "ARL-none"
          Thread.current.abort_on_exception = false
          puts "#{self.class}: started thread".colorize(:light_blue)
          yield
        end
      end

      def listen(channel, &block)
        threaded do
          Thread.current.name = "ARL-#{channel}"
          with_notify_connection do |conn|
            puts "#{self.class}: Will LISTEN on #{conn.inspect}".colorize(:light_blue)
            conn.exec "LISTEN #{channel}"

            catch :shutdown do
              @listening = true

              puts "#{self.class}: (waiting for NOTIFY...)".colorize(:light_blue)
              loop do
                conn.wait_for_notify(1) do |channel, _pid, payload|
                  puts 'NOTIFY'.colorize(color: :white, background: :light_blue) + "channel: #{channel}; payload: #{payload.inspect}"

                  begin
                    case block.arity
                    when 1 then yield payload
                    when 2 then yield channel, payload
                    when 3 then yield channel, payload, conn
                    else raise ArgumentError.new("Invalid arguments to listen handler. (Expected 1..3, got #{block.arity})")
                    end
                  rescue Exception => e
                    puts "Exception in 'LISTEN #{channel}' handler: #{e.message}".colorize(:red)
                    e.backtrace.each do |line|
                      puts '    '+ line
                    end
                  end
                end#wait_for_notify
              end#loop
            end #catch
            
          ensure # in with_notify_connection
            conn.exec "UNLISTEN #{channel}" unless conn.nil?
          end
        end
      end

    end
  end
end
