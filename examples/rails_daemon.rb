require 'rubygems'
require 'i_can_daemonize'
begin
  require File.dirname(__FILE__) + "/../config/environment"
rescue LoadError
  puts "\n****** ERROR LOADING RAILS ******\n\trails_daemon.rb should be put in your RAILS_ROOT/script directory so it can find your environment.rb\n\tOr you can change the environment require on line 4.\n*********************************\n\n"
end

class ICanDaemonize::SimpleDaemon
  include ICanDaemonize
  
  before do
    puts "This daemon has access to your entire rails stack and will log to RAILS_ROOT/log"
  end

  after do
    puts "The after block is executed before the program exits gracefully, but is not run if the program dies."
  end
  
  die_if do
    puts "The die_if block is executed after every loop and dies if true is returned."
    false
  end

  exit_if do
    puts "The exit_if block is executed after every loop and exits gracefully if true is returned."
    false
  end
  
  daemonize(:loop_every => 3, :timeout=>2, :die_on_timeout => false) do
    puts "The daemonize block is called in a loop."
  end
  
end