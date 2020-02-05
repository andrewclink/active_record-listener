# frozen_string_literal: true

module ActiveRecord
  module Listener
    class Base

      def initialize
        @listening = false
        @channel = nil
        @queue = []
      end

      def verify!(pg_conn)
        return if pg_conn.is_a?(PG::Connection)
        raise 'The Active Record database must be PostgreSQL in order to use LISTEN/NOTIFY with ActiveRecordListener'
      end

      def with_notify_connection
        ar_conn = ActiveRecord::Base.connection_pool.checkout

        if ar_conn.nil?
          Rails.logger.error 'ActiveRecord::Listener::Base: could not get connection!'.colorize(:red)
          return
        end

        # ActiveRecord::Listener is taking ownership over this database connection, and
        # will perform the necessary cleanup tasks
        ActiveRecord::Base.connection_pool.remove(ar_conn)

        pg_conn = ar_conn.raw_connection
        verify! pg_conn
        
        yield pg_conn

      rescue PG::ConnectionBad, ActiveRecord::NoDatabaseError
        # Let's not be the bearer of bad news. Specifically, let's not cause 
        # rake db:create to fail because the database doesn't yet exist
        Rails.logger.error "#{self.class}[#{Process.pid}] (#@channel): Received PG::ConnectionBad. Ignoring (and not listening)".colorize(:yellow)
        return nil
        
      ensure
        puts "ActiveRecord::Listener::Base[#{Process.pid}]: ar_conn.disconnect! #{ar_conn}".colorize(:red)
        ar_conn.disconnect! unless ar_conn.nil?
      end

      # This runs on the listener thread
      def threaded(&block)
        @thread = Thread.new do
          Thread.current.name = "ARL-none"
          Thread.current.abort_on_exception = false
          yield
        end
      end

      public

      def unlisten
        # This will cause the thread to hit its ensure block,
        # which will unlisten on the connection if possible.
        @thread.exit if @thread.alive?
        @thread = nil
      end

      def listen(channel, &block)
        Rails.logger.debug "ActiveRecord::Listener::Base: '#{channel}' in_rake? #{ActiveRecord::Listener.in_rake_task?}"
        
        return Rails.logger.debug "#{self.class}: LISTEN suppressed in rake task" if ActiveRecord::Listener.in_rake_task?
        return if channel.nil?
        return unless block_given?
        
        @channel = channel
        
        threaded do
          Thread.current.name = "ARL-#{channel}"
          with_notify_connection do |conn|
            Rails.logger.debug "#{self.class}: LISTEN '#{channel}'on #{conn.inspect}".colorize(:light_blue)
            
            conn.exec("SET application_name = 'ARL-#{channel}'")

            stmt = "LISTEN #{conn.escape_identifier(channel)}"
            Rails.logger.debug "#{'ActiveRecord::Listener::Base:'.colorize(:light_blue)} #{stmt}"
            conn.exec stmt
            
            # Also listen for the disconnect hook. If we're forked into a rake process (rspec)
            # we need to immediately relinquish the database so it can be dropped, migrated, etc.
            #
            stmt = "LISTEN #{conn.escape_identifier('arl_disconnect_hook')}"
            conn.exec stmt
            

            catch :shutdown do
              @listening = true

              #Rails.logger.debug "#{self.class}: (waiting for NOTIFY...)".colorize(:light_blue)
              loop do
                conn.wait_for_notify(0.1) do |channel, _pid, payload|
                  throw(:shutdown) if channel == 'arl_disconnect_hook'

                  #puts 'recv NOTIFY'.colorize(color: :white, background: :light_blue) + " channel: #{channel}; payload: #{payload}"

                  begin
                    case block.arity
                    when 1 then yield payload
                    when 2 then yield channel, payload
                    when 3 then yield channel, payload, conn
                    else raise ArgumentError.new("Invalid arguments to listen handler. (Expected 1..3, got #{block.arity})")
                    end
                  rescue Exception => e
                    Rails.logger.error "Exception in 'LISTEN #{channel}' handler: #{e.message}".colorize(:red)
                    e.backtrace.each do |line|
                      Rails.logger.info '    '+ line
                    end
                  end
                end #wait_for_notify
              end #loop
            end #catch
            
          ensure # in with_notify_connection
            Rails.logger.debug "ARL (#{channel}): Thread exiting in pid #{Process.pid}"
            begin
              conn.exec "UNLISTEN #{channel}" unless conn.nil?
              conn.close
            rescue PG::UnableToSend
              # We don't need to UNLISTEN on a connection that has apparently been closed.
              Rails.logger.error "ARL: UnableToSend UNLISTEN in pid #{Process.pid} (child: #{Rails::application.is_forked?})"
            end
          end
        end
      end

    end
  end
end
