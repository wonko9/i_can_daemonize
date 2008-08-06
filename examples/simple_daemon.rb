require 'rubygems'
require 'i_can_daemonize'

class ICanDaemonize::FeatureDemo
  include ICanDaemonize

  daemonize(:loop_every => 3) do
    puts "The daemonize block is called in a loop."
  end

end