$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

  require 'optparse'
  require 'timeout'    

  module ICanDaemonize
    class DieTime < StandardError; end
    class TimeoutError < StandardError; end

    def self.included(base)
      base.extend ClassMethods
      base.parse_options
    end

    module ClassMethods  
      def parse_options
        @options   = {
          :pid_dir    => (File.exists?("log/") ? File.expand_path("log/") : File.expand_path(".")),
          :log_dir    => (File.exists?("log/") ? File.expand_path("log/") : File.expand_path(".")),        
        }      
        @log_prefix = true
        @callbacks = {}

        @argv = ARGV
        @opts = OptionParser.new do |opt|
          #opts.banner = "Usage: example.rb [options]"
          opt.banner = "Usage: #{script_name} [options] [start|stop]"

          opt.on_tail("-h", "--help", "Show this message") do
            puts opt
            exit
          end
          opt.on("--loop-every=LOOPEVERY", "How long to sleep between each loop") do |t|
            @options[:loop_every] = t
          end
          opt.on("-t", "--ontop", "Stay on top (does not daemonize)") do |t|
            @options[:ontop] = t
          end

          opt.on('--instances=NUM', 'Allow multiple instances to run simultaneously? 0 for infinite. default: 1') do |v|
            @instances = v.to_i
          end
          opt.on('--logdir=LOGDIR', 'Logfile to log to') do |v|
            @options[:log_dir] = File.expand_path(v)
          end
          opt.on('--logfile=LOGFILE', 'Logfile to log to') do |v|
            @options[:log_file] = File.expand_path(v)
          end
          opt.on('--loglevel=LOGLEVEL', 'Log level defaults to DEBUG') do |v|
            @options[:log_level] = v
          end
          opt.on('--logprefix=TRUE_OR_FALSE', 'All output to logfiles will be prefixed with PID and date/time.') do |v|
            if v.downcase == "false" or v == "0"
              @log_prefix = false
            end
          end
          opt.on('--pid_file=PIDFILE', 'Directory to put pidfile') do |v|
            @options[:pid_dir] = File.expand_path(v)
          end
        end
        @opts.parse!
        @options[:ontop]   ||= !ARGV.include?('start')

        if ARGV.include?('stop')                                                         
          @instances ||= 0
          stop(@instances)
        elsif ARGV.include?('start')
          @instances ||= 1
          @running = true
        else
          puts @opts.help
        end
      end

      def before(&block)
        @callbacks[:before] = block
      end

      def after(&block)
        @callbacks[:after] = block
      end

      def die_if(method=nil,&block)
        @options[:die_if] = method || block
      end

      def exit_if(method=nil,&block)
        @options[:exit_if] = method || block
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
      def daemonize(options={},&block)
        return unless ok_to_start?
        @options.merge!(options)
        puts "Starting #{script_name} instances: #{(@instances - read_pid_file.size)}"
        if not @options[:ontop]
          (@instances - read_pid_file.size).times do
            safefork do
              add_pid_to_pidfile
              trap("TERM") { exit(0) }
              sess_id = Process.setsid
              reopen_filehandes
              @before ||= {} 
              begin
                at_exit { @callbacks[:after].call if @callbacks[:after] }
                @callbacks[:before].call if @callbacks[:before]
                run_block(&block)
              rescue SystemExit
              rescue Exception => e
                $stdout.puts "Something bad happened #{e.inspect} #{e.backtrace.join("\n")}"
              end
            end
          end
        else
          @callbacks[:before].call if @callbacks[:before]
          run_block(&block)
          @callbacks[:after].call if @callbacks[:after]
        end
      end

      private

      LOG_FORMAT = "%-6d %-19s %s"
      def reopen_filehandes
        STDIN.reopen("/dev/null")
        STDOUT.reopen(log_file, "a")
        STDOUT.sync = true          
        STDERR.reopen(STDOUT)
        if @log_prefix
          def STDOUT.write(string)
            if string and not string.rstrip.empty?
              # super(string)
              string = LOG_FORMAT % [$$,Time.now.strftime("%Y/%m/%d %H:%M:%S"),string]
            end
            super(string)
          end
        end
      end

      def ok_to_start?
        return false unless @running
        pids = read_pid_file
        living_pids = []
        if pids and pids.any?
          pids.each do |pid|
            if process_alive?(pid)                                                 
              living_pids << pid
            else
              $stderr.puts "Removing stale pid: #{pid}"
            end
          end
          if @instances > 0 and living_pids.size >= @instances
            $stderr.puts "#{script_name} is already running #{living_pids.size} out of #{@instances} instances"
            return false          
          end
        end
        return true
      end

      def run_block(&block)
        loop do
          break unless @running
          if @options[:timeout]
            begin
              Timeout::timeout(@options[:timeout].to_i) do
                block.call
              end
            rescue Timeout::Error => e
              if @options[:die_on_timeout]
                raise TimeoutError.new("#{self} Timed out after #{@options[:timeout]} seconds while executing block in loop")
              else
                $stderr.puts "#{self} Timed out after #{@options[:timeout]} seconds while executing block in loop #{e.backtrace.join("\n")}"
              end
            end            
          else
            block.call            
          end
          sleep @options[:loop_every].to_i if @options[:loop_every]
          break if should_exit?
          raise DieTime.new("Die if conditions were met!") if should_die?
        end
        exit
      end

      def should_die?
        if @options[:die_if]
          if @options[:die_if].is_a?(Symbol) or @options[:die_if].is_a?(String)
            self.send(@options[:die_if])
          elsif @options[:die_if].is_a?(Proc)
            @options[:die_if].call
          end
        else
          false
        end
      end

      def should_exit?
        if @options[:exit_if]
          if @options[:exit_if].is_a?(Symbol) or @options[:exit_if].is_a?(String)
            self.send(@options[:exit_if].to_sym)
          elsif @options[:exit_if].is_a?(Proc)
            @options[:exit_if].call
          end
        else
          false
        end
      end

      def restart
        ### MUST IMPLEMENT  ## RESTART WITH @argv
      end                 

      ################################################################################
      # stop the daemon, nicely at first, and then forcefully if necessary
      def stop(number_of_pids_to_stop=0)
        puts "stopping #{number_of_pids_to_stop} pids"
        @running = false      
        pids = read_pid_file
        if pids.empty?
          $stderr.puts "#{script_name} doesn't appear to be running"
          exit
        end
        pids.each_with_index do |pid,ii|
          begin
            $stdout.puts("stopping pid: #{pid} #{script_name}...")
            Process.kill("TERM", pid)
            30.times { Process.kill(0, pid); sleep(0.5) }
            $stdout.puts("using kill -9 #{pid}")
            Process.kill(9, pid)
            puts "ii == (number_of_pids_to_stop - 1) #{ii} == #{(number_of_pids_to_stop - 1)}"
          rescue Errno::ESRCH => e
            $stdout.puts("process #{pid} has stopped")
          ensure
            break if ii == (number_of_pids_to_stop - 1)
          end
        end
      end

      ################################################################################
      def safefork (&block)
        @fork_tries ||= 0
        fork(&block)
      rescue Errno::EWOULDBLOCK
        raise if @fork_tries >= 20
        @fork_tries += 1
        sleep 5
        retry
      end

      def process_alive?(process_pid)
        Process.kill(0,process_pid)
        return true
      rescue Errno::ESRCH => e
        return false
      end  

      #################################################################################
      # create the PID file and install an at_exit handler
      def add_pid_to_pidfile
        open(pid_file, "a+") {|f| f << Process.pid << "\n"}
        at_exit { remove_self_from_pidfile }
        # puts "adding #{Process.pid} to pidfile"
      end

      def rewrite_pidfile(pids)
        if pids.any?
          open(pid_file,"w") {|f| f << pids.join("\n") << "\n"}
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

      #################################################################################
      def read_pid_file
        if File.exist?(pid_file)
          File.readlines(pid_file).collect {|p| p.to_i}
        else
          []
        end
      end

      def log_file
        File.expand_path(@options[:log_dir] + "/#{script_name}.log")
      end

      def pid_file
        File.expand_path(@options[:pid_dir] + "/#{script_name}.pid")
      end

      def script_name
        @script_name ||= File.basename($0)      
      end

      def script_name=(script_name)
        @script_name = script_name
      end

      def underscore(camel_cased_word)
        camel_cased_word.to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr("-", "_").
          downcase
      end           
    end
  end
