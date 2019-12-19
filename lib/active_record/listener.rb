# frozen_string_literal: true

require "active_record/listener/version"

require_relative 'listener/base'

module ActiveRecord
  module Listener
    class Error < StandardError; end

    def self.listen(channel, &block)
      puts "ActiveRecord::Listener.listen(#{channel.inspect})".colorize(:light_blue)
      
      Base.new.tap do |listener|
        listener.listen(channel, &block)
      end
      
    end
  end
end
