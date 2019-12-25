require 'rake'

RSpec.describe ActiveRecord::Listener do
  
  let(:rake) {
    Rails.application.load_tasks
    Rake::Task
  }
  
  it "doesn't impede database creation" do
    puts "Will call db:create"
    ENV['RAILS_ENV'] = 'production'
    task = rake['db:create']
    ret = task.actions.first.call(task)
    puts "Got ret: #{ret.inspect}"
  end

end
