require 'rubygems'
require 'pp'
require 'i_can_daemonize'
begin
  require 'starling'
rescue LoadError
  puts "\n****** ERROR LOADING STARLING ******\n\tStarling is not installed.  Please run 'sudo gem install starling' before running this script.\n*********************************\n\n"
end

class ICanDaemonize::StarlingDaemon
  include ICanDaemonize

  if ARGV.include?('start')
    puts <<-DOC 

    This daemon will listen to a starling queue called '#{@queue_name}' and print out whatever is added
    First tail this daemon's log in another window.  
    The log is @ #{log_file}
    Run irb at the console and type
    > require 'rubygems'
    > require 'starling'
    > starling = Starling.new('127.0.0.1:22122')
    > starling.set('#{@queue_name}','Hi there!')
    Now watch the log file.

    DOC
  end
  
  before do
    @queue_name = "starlingdeamon"
    @starling = Starling.new("127.0.0.1:22122")
    @fetch_count = 0
  end
  
  daemonize(:log_prefix => false) do
    puts "Trying to fetch from the '#{@queue_name}' queue. Dequeued #{@fetch_count} so far"
    pp "GOT: ", @starling.get(@queue_name)
    @fetch_count += 1
  end
  
end