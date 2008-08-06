require 'rubygems'
require 'i_can_daemonize'

class ICanDaemonize::FeatureDemo
  include ICanDaemonize
  
  def self.define_args(args)
    # "See the OptionParser docs for more info on how to define your own args.\n http://www.ruby-doc.org/stdlib/libdoc/optparse/rdoc/classes/OptionParser.html\n"
    @options[:nobugs] = true
    args.on("--scott-rocks=TRUE", "Thanks scott") do |t|
      @options[:scott_rocks] = t
    end                   
    args.on("--nobugs=TRUE", "No bugs flag") do |t|
      @options[:nobugs] = false if t == "1" or t.downcase == "false"
    end                   
  end
  
  before do
    puts "The before block is executed after daemonizing, but before looping over the daemonize block"
    if @options[:nobugs]
      puts "Running with no bugs. Pass nobugs=false to run with bugs."
    else
      puts "There mite be busg"
    end
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