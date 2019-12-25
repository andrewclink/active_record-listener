# frozen_string_literal: true

ActiveRecord::Listener.listen('placements') do |channel, payload, conn|
  puts "Listen Reactor: got NOTIFY #{channel} payload: #{payload.inspect}"
end
