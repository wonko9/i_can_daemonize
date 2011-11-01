require 'optparse'
require 'timeout'    

module ICanDaemonize
  class DieTime < StandardError; end
  class TimeoutError < StandardError; end

  def self.included(base)
    base.extend ClassMethods           
    base.initialize_options
  end

  class Config
    METHODS = [:script_path]
    CONFIG = {}    
    def method_missing(name, *args)
      name = name.to_s.upcase.to_sym
      if name.to_s =~ /^(.*)=$/
        name = $1.to_sym
        CONFIG[name] = args.first
      else
        CONFIG[name]
      end
    end    
  end

  module ClassMethods  
 
    def initialize_options    
      @@config             = Config.new
      @@config.script_path = File.expand_path(File.dirname($0))
      $0                   = script_name
    end
    
    def parse_options
      opts = OptionParser.new do |opt|
        opt.banner = "Usage: #{script_name} [options] [start|stop]"

        opt.on_tail('-h', '--help', 'Show this message') do
          puts opt
          exit(1)
        end

        opt.on('--loop-every=SECONDS', 'How long to sleep between each loop') do |value|
          options[:loop_every] = value 
        end

        opt.on('-t', '--ontop', 'Stay on top (does not daemonize)') do
          options[:ontop] = true
        end

        opt.on('--instances=NUM', 'Allow multiple instances to run simultaneously? 0 for infinite. default: 1') do |value|
          self.instances = value.to_i
        end

        opt.on('--log-file=LOGFILE', 'Logfile to log to') do |value|
          options[:log_file] = File.expand_path(value)
        end

        opt.on('--pid-file=PIDFILE', 'Location of pidfile') do |value|
          options[:pid_file] = File.expand_path(value)
        end

        opt.on('--no-log-prefix', 'Do not prefix PID and date/time in log file.') do
          options[:log_prefix] = false
        end
      end
      
      extra_args.each do |arg|
        opts.on(*arg.first) do |value|
          arg.last.call(value) if arg.last
        end
      end

      opts.parse!
      
      if ARGV.include?('stop')                                                         
        stop_daemons
      elsif ARGV.include?('restart')
        restart_daemons
      elsif ARGV.include?('rotate')
        rotate_daemons
      elsif ARGV.include?('start') or ontop?
        self.running   = true
        self.restarted = true if ARGV.include?('HUP')
      else
        puts opts.help
      end
    end    

    def arg(*args, &block)
      self.extra_args << [args, block]
    end

    def extra_args
      @extra_args ||= [] 
    end

    def callbacks
      @callbacks ||= {}
    end

    def options
      @options ||= {}
    end

    def options=(options)
      @options = options
    end

    def config
      yield @@config
    end
    
    def before(&block)
      callbacks[:before] = block
    end

    def after(&block)
      callbacks[:after] = block
    end

    def sig(*signals, &block)
      signals.each do |s|
        callbacks["sig_#{s}".to_sym] = block
      end
    end

    def die_if(method=nil,&block)
      options[:die_if] = method || block
    end

    def exit_if(method=nil,&block)
      options[:exit_if] = method || block
    end

    def callback!(callback)
      callbacks[callback].call if callbacks[callback]
    end

    # options may include:
    #
    # <tt>:loop_every</tt> Fixnum (DEFAULT 0)
    #  How many seconds to sleep between calls to your block
    #
    # <tt>:timeout</tt> Fixnum (DEFAULT 0)
    #  Timeout in if block does not execute withing passed number of seconds
    #
    # <tt>:kill_timeout</tt> Fixnum (DEFAULT 120)
    #  Wait number of seconds before using kill -9 on daemon
    #
    # <tt>:die_on_timeout</tt> BOOL (DEFAULT False)
    #  Should the daemon continue running if a block times out, or just run the block again
    #
    # <tt>:ontop</tt> BOOL (DEFAULT False)
    #  Do not daemonize.  Run in current process
    #
    # <tt>:before</tt> BLOCK
    #  Run this block after daemonizing but before begining the daemonize loop.
    #  You can also define the before block by putting a before do/end block in your class.
    #
    # <tt>:after</tt> BLOCK
    #  Run this block before program exists.  
    #  You can also define the after block by putting an after do/end block in your class.
    #
    # <tt>:die_if</tt> BLOCK
    #  Run this check after each iteration of the loop.   If the block returns true, throw a DieTime exception and exit
    #  You can also define the after block by putting an die_if do/end block in your class.
    #      
    # <tt>:exit_if</tt> BLOCK
    #  Run this check after each iteration of the loop.   If the block returns true, exit gracefully
    #  You can also define the after block by putting an exit_if do/end block in your class.
    #
    # <tt>:log_prefix</tt> BOOL (DEFAULT true)
    #  Prefix log file entries with PID and timestamp
    def daemonize(opts={}, &block)
      self.options = opts
      parse_options
      return unless ok_to_start?

      puts "Starting #{instances_to_start} #{script_name} #{pluralize('instance', instances_to_start)}..."
      puts "Logging to: #{log_file}" unless ontop?
      
      unless ontop?
        instances_to_start.times do
          safefork do
            open(pid_file, 'a+') {|f| f << Process.pid << "\n"}
            at_exit { remove_pid! }

      
            trap('TERM') { callback!(:sig_term) ; self.running = false     }
            trap('INT')  { callback!(:sig_int)  ; Process.kill('TERM', $$) }
            trap('HUP')  { callback!(:sig_hup)  ; restart_self             }
            trap('USR1') { callback!(:sig_usr1) ; puts "Reopening LOG filehandle"; reopen_filehandes        }

            sess_id = Process.setsid
            reopen_filehandes

            begin
              at_exit { callback!(:after) }
              callback!(:before)
              run_block(&block)
            rescue SystemExit
            rescue Exception => e
              $stdout.puts "Something bad happened #{e.inspect} #{e.backtrace.join("\n")}"
            end            
          end
        end
      else
        begin
          callback!(:before)
          run_block(&block)
        rescue SystemExit, Interrupt
          callback!(:after)
        end
      end
    end

    private
    
    def run_block(&block)
      loop do
        break unless running?

        if options[:timeout]
          begin
            Timeout::timeout(options[:timeout].to_i) do
              block.call if block              
            end
          rescue Timeout::Error => e
            if options[:die_on_timeout]
              raise TimeoutError.new("#{self} timed out after #{options[:timeout]} seconds while executing block in loop")
            else
              $stderr.puts "#{self} timed out after #{options[:timeout]} seconds while executing block in loop #{e.backtrace.join("\n")}"
            end
          end            
        else
          block.call if block
        end

        if options[:loop_every]
          sleep options[:loop_every].to_i
        elsif not block
          sleep 0.1
        end

        break if should_exit?
        raise DieTime.new('Die if conditions were met!') if should_die?
      end                    
      exit(0)
    end

    def should_die?
      die_if = options[:die_if]
      if die_if
        if die_if.is_a?(Symbol) or die_if.is_a?(String)
          self.send(die_if)
        elsif die_if.is_a?(Proc)
          die_if.call
        end
      else
        false
      end
    end

    def should_exit?
      exit_if = options[:exit_if]
      if exit_if
        if exit_if.is_a?(Symbol) or exit_if.is_a?(String)
          self.send(exit_if.to_sym)
        elsif exit_if.is_a?(Proc)
          exit_if.call
        end
      else
        false
      end
    end

    def instances_to_start
      return 1 if restarted?
      instances - pids.size      
    end

    def ok_to_start?
      return false unless running?
      return true if restarted?

      living_pids = []
      if pids and pids.any?
        pids.each do |pid|
          if process_alive?(pid)                                                 
            living_pids << pid
          else
            $stderr.puts "Removing stale pid: #{pid}..."
            pids.delete(pid)
            self.pids = pids
          end
        end
        if instances > 0 and living_pids.size >= instances
          $stderr.puts "#{script_name} is already running #{living_pids.size} out of #{instances} #{pluralize('instance', instances)}"
          return false          
        end
      end
      return true
    end

    # stop the daemon, nicely at first, and then forcefully if necessary
    def stop_daemons
      self.running = false      
      pids_to_stop = @instances || pids.size
      puts "Stopping #{pids_to_stop} #{script_name} #{pluralize('instance', pids_to_stop)}..."
      if pids.empty?
        $stderr.puts "#{script_name} doesn't appear to be running"
        exit(1)
      end
      pids.each_with_index do |pid, ii|
        kill_pid(pid)
        break if ii == (pids_to_stop - 1)
      end
    end     

    def rotate_daemons
      if pids.empty?
        $stdout.puts "#{script_name} doesn't appear to be running!"
        exit(1)
      end

      $stdout.puts "Sending SIGUSR1 to #{pids.join(', ')} ..."
      pids.each do |pid|
        begin 
          Process.kill('USR1', pid)
        rescue Errno::ESRCH
          $stdout.puts("Couldn't send USR1 #{pid} as it wasn't running")
        end
      end
    end

    def restart_daemons
      pids.each do |pid|
        kill_pid(pid, 'HUP')
      end
    end
    
    def kill_pid(pid, signal='TERM')
      $stdout.puts("Stopping pid #{pid} with #{signal}...")
      begin
        Process.kill(signal, pid)             
        if pid_running?(pid, options[:kill_timeout] || 120)
          $stdout.puts("Using kill -9 #{pid}")
          Process.kill(9, pid)
        else
          $stdout.puts("Process #{pid} stopped")
        end
      rescue Errno::ESRCH
       $stdout.puts("Couldn't #{signal} #{pid} as it wasn't running")
      end
    end               
    
    def pid_running?(pid,time_to_wait=0)
      times_to_check = 1
      if time_to_wait > 0.5
        times_to_check = (time_to_wait / 0.5).to_i
      end
            
      begin
        times_to_check.times do
          Process.kill(0, pid)
          sleep 0.5
        end
        return true
      rescue Errno::ESRCH
        return false
      end      
    end
          
    def restart_self
      remove_pid!
      cmd = "#{@@config.script_path}/#{script_name} "
      cmd << 'HUP ' unless ARGV.include?('HUP')
      cmd << ARGV.join(' ')
      puts "Restarting #{cmd} pid: #{$$}..."
      system(cmd)  
      sleep 2
      Process.kill('TERM', $$)
    end
        
    def safefork(&block)
      fork_tries ||= 0
      fork(&block)
    rescue Errno::EWOULDBLOCK
      raise if fork_tries >= 20
      fork_tries += 1
      sleep 5
      retry
    end

    def process_alive?(process_pid)
      Process.kill(0, process_pid)
      return true
    rescue Errno::ESRCH => e
      return false
    end  

    LOG_FORMAT  = '%-6d %-19s %s'
    TIME_FORMAT = '%Y/%m/%d %H:%M:%S'
    def reopen_filehandes
      STDIN.reopen('/dev/null')
      STDOUT.reopen(log_file, 'a')
      STDOUT.sync = true          
      STDERR.reopen(STDOUT)

      if log_prefix?
        def STDOUT.write(string)
          if @no_prefix
            @no_prefix = false if string[-1, 1] == "\n"
          else
            string = LOG_FORMAT % [$$, Time.now.strftime(TIME_FORMAT), string]
            @no_prefix = true              
          end
          super(string)
        end
      end
    end

    def remove_pid!(pid=Process.pid)
      pids.delete(pid)
      self.pids = pids
    end

    def pids=(pids)
      if pids.any?
        open(pid_file, 'w') {|f| f << pids.join("\n") << "\n"}
      else
        File.unlink(pid_file) if File.exists?(pid_file)
      end
      @pids = pids
    end

    def pids
      @pids ||= begin
        if File.exist?(pid_file)
          File.readlines(pid_file).collect {|p| p.to_i}
        else
          []
        end
      end
    end

    def instances=(num)
      @instances = num
    end

    def instances
      @instances || 1
    end

    def pluralize(name, num)
      num == 1 ? name : "#{name}s"
    end

    def running?
      @running || false
    end

    def running=(bool)
      @running = bool
    end

    def restarted?
      @restarted || false
    end

    def restarted=(bool)
      @restarted = bool
    end

    def ontop?
      options[:ontop]
    end

    def log_prefix?
      options[:log_prefix] || true
    end                    
    
    LOG_PATHS = ['log/', 'logs/', '../log/', '../logs/', '../../log', '../../logs', '.']
    
    if defined?(Rails)
      LOG_PATHS.unshift(Rails.root.join('log')) unless Rails.root.nil?
    elsif defined?(RAILS_ROOT)
      LOG_PATHS.unshift("#{RAILS_ROOT}/log")
    end
    
    def log_dir
      options[:log_dir] ||= begin
        LOG_PATHS.detect do |path|
          File.exists?(File.expand_path(path))        
        end
      end               
    end
    
    def log_file
      options[:log_file] ||= File.expand_path("#{log_dir}/#{script_name}.log")
    end

    def pid_dir
      options[:pid_dir] ||= log_dir
    end

    def pid_file
      options[:pid_file] ||= File.expand_path("#{pid_dir}/#{script_name}.pid")
    end

    def script_name
      @script_name ||= File.basename($0).gsub('.rb', '')
    end

    def script_name=(script_name)
      @script_name = script_name
    end

  end
end
