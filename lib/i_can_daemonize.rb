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
          exit
        end

        opt.on('--loop-every=SECONDS', 'How long to sleep between each loop') do |value|
          options[:loop_every] = value 
        end

        opt.on('-t', '--ontop', 'Stay on top (does not daemonize)') do |value|
          options[:ontop] = value
        end

        opt.on('--instances=NUM', 'Allow multiple instances to run simultaneously? 0 for infinite. default: 1') do |value|
          @instances = value.to_i
        end

        opt.on('--log-file=LOGFILE', 'Logfile to log to') do |value|
          options[:log_file] = File.expand_path(value)
        end

        opt.on('--pid-file=PIDFILE', 'Location of pidfile') do |value|
          options[:pid_file] = File.expand_path(value)
        end

        opt.on('--log-prefix=BOOLEAN', 'All output to logfiles will be prefixed with PID and date/time.') do |value|
          if value.downcase == 'false' or value == '0'
            options[:log_prefix] = false
          end
        end
      end
      
      extra_args.each do |arg|
        opts.on(*arg.first) do |value|
          arg.last.call(value) if arg.last
        end
      end

      opts.parse!
      options[:ontop] ||= !ARGV.include?('start')
      
      if ARGV.include?('stop')                                                         
        @instances ||= 0
        stop_daemons(@instances)
      elsif ARGV.include?('restart')
        restart_daemons
      elsif ARGV.include?('start')
        @instances ||= 1
        @running     = true
        @restarted   = true if ARGV.include?("HUP")
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
      @options ||= {:log_prefix => true}
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

    def sig(signal, &block)
      callbacks["sig_#{signal}".to_sym] = block
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
    # <tt>:log_prefix</tt> BOOL (DEFAULT false)
    #  Prefix log file entries with PID and timestamp
    def daemonize(options={},&block)
      parse_options
      return unless ok_to_start?

      options.merge!(options)
      puts "Starting #{script_name} instances: #{instances_to_start}  Logging to: #{log_file}"
      
      if not options[:ontop]
        instances_to_start.times do
          safefork do
            add_pid_to_pidfile

            trap('TERM') { callback!(:sig_term) ; stop;                     }
            trap('INT')  { callback!(:sig_int)  ; Process.kill('TERM', $$)  }
            trap('HUP')  { callback!(:sig_hup)  ; restart_self              }

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
        break unless @running
        if options[:timeout]
          begin
            Timeout::timeout(options[:timeout].to_i) do
              block.call if block              
            end
          rescue Timeout::Error => e
            if options[:die_on_timeout]
              raise TimeoutError.new("#{self} Timed out after #{options[:timeout]} seconds while executing block in loop")
            else
              $stderr.puts "#{self} Timed out after #{options[:timeout]} seconds while executing block in loop #{e.backtrace.join("\n")}"
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
        raise DieTime.new("Die if conditions were met!") if should_die?
      end                    
      exit(0)
    end

    def should_die?
      if options[:die_if]
        if options[:die_if].is_a?(Symbol) or options[:die_if].is_a?(String)
          self.send(options[:die_if])
        elsif options[:die_if].is_a?(Proc)
          options[:die_if].call
        end
      else
        false
      end
    end

    def should_exit?
      if options[:exit_if]
        if options[:exit_if].is_a?(Symbol) or options[:exit_if].is_a?(String)
          self.send(options[:exit_if].to_sym)
        elsif options[:exit_if].is_a?(Proc)
          options[:exit_if].call
        end
      else
        false
      end
    end

    def instances_to_start
      return 1 if @restarted
      @instances - read_pid_file.size      
    end

    def ok_to_start?
      return false unless @running
      return true if @restarted
      pids = read_pid_file
      living_pids = []
      if pids and pids.any?
        pids.each do |pid|
          if process_alive?(pid)                                                 
            living_pids << pid
          else
            $stderr.puts "Removing stale pid: #{pid}"
            pids -= [pid]
            rewrite_pidfile(pids)
          end
        end
        if @instances > 0 and living_pids.size >= @instances
          $stderr.puts "#{script_name} is already running #{living_pids.size} out of #{@instances} instances"
          return false          
        end
      end
      return true
    end

    # stop the daemon, nicely at first, and then forcefully if necessary
    def stop_daemons(number_of_pids_to_stop=0)      
      @running = false      
      pids = read_pid_file            
      number_of_pids_to_stop = pids.size if number_of_pids_to_stop == 0
      puts "stopping #{number_of_pids_to_stop} pids"
      if pids.empty?
        $stderr.puts "#{script_name} doesn't appear to be running"
        exit
      end
      pids.each_with_index do |pid,ii|
        kill_pid(pid)
        break if ii == (number_of_pids_to_stop - 1)
      end
    end     

    def restart_daemons
      read_pid_file.each do |pid|
        kill_pid(pid, 'HUP')
      end
    end
    
    def stop
      @running = false
    end
    
    def kill_pid(pid,signal="TERM")
      $stdout.puts("stopping pid: #{pid} sig: #{signal} #{script_name}...")
      begin
        Process.kill(signal, pid)             
        if pid_running?(pid, options[:timeout] || 120)
          $stdout.puts("using kill -9 #{pid}")
          Process.kill(9, pid)
        else
          $stdout.puts("process #{pid} has stopped")
        end
      rescue Errno::ESRCH
       $stdout.puts("couldn't #{signal} #{pid} as it wasn't running")
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
      remove_self_from_pidfile
      cmd = "#{@@config.script_path}/#{script_name} "
      cmd << 'HUP ' unless ARGV.include?('HUP')
      cmd << ARGV.join(' ')
      puts "restarting #{cmd} pid: #{$$}"
      system(cmd)        
      Process.kill('TERM', $$)
    end
        
    def safefork(&block)
      @fork_tries ||= 0
      fork(&block)
    rescue Errno::EWOULDBLOCK
      raise if @fork_tries >= 20
      @fork_tries += 1
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
            @no_prefix = false if string[-1,1] == "\n"
          else
            string = LOG_FORMAT % [$$,Time.now.strftime(TIME_FORMAT),string]
            @no_prefix = true              
          end
          super(string)
        end
      end
    end

    # create the PID file and install an at_exit handler
    def add_pid_to_pidfile
      open(pid_file, 'a+') {|f| f << Process.pid << "\n"}
      at_exit { remove_self_from_pidfile }
    end

    def rewrite_pidfile(pids)
      if pids.any?
        open(pid_file, 'w') {|f| f << pids.join("\n") << "\n"}
      else
        remove_pidfile
      end
    end

    def remove_self_from_pidfile
      pids = read_pid_file
      pids.delete(Process.pid)
      rewrite_pidfile(pids)
    end

    def remove_pidfile
      File.unlink(pid_file) if File.exists?(pid_file)
    end

    def read_pid_file
      if File.exist?(pid_file)
        File.readlines(pid_file).collect {|p| p.to_i}
      else
        []
      end
    end

    def log_prefix?
      options[:log_prefix]      
    end                    
    
    LOG_PATHS = ['log/', 'logs/', '../log/', '../logs/', '../../log', '../../logs', '.']
    LOG_PATHS.unshift("#{RAILS_ROOT}/log") if defined?(RAILS_ROOT)
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
      @script_name ||= File.basename($0)
    end

    def script_name=(script_name)
      @script_name = script_name
    end
  end
end
