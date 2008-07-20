= i_can_daemonize

* FIX http://???

== DESCRIPTION:

ICanDaemonize makes it dead simple to create daemons of your own.

== REQUIREMENTS:

* A Computer
* Ruby

== INSTALL:

* Get ICanDaemonize off github

== THE BASICS:

  require 'rubygems'
  require 'i_can_daemonize'
  class MyDaemonClass
    include ICanDaemonize
    
    daemonize do
      # your code here
    end
    
  end

Run your daemon

  ruby your_daemon_script start
  
ICD will create a log file in log/ called your_daemon_script.log as well as a pid file in log called your_daemon_script.pid

It will essentially run the block given to daemonize within a loop.

== USAGE:

The daemonize method accepts a number of options see ICanDaemonize::ClassMethods daemonize() for options

There are a number of other blocks you can define in your class as well, including:

  before do/end

  after do/end

  die_if do/end

  exit_if do/end

See ICanDaemonize docs for more info on these options.

Your daemon can be called with a number of options

      --loop-every LOOPEVERY       How long to sleep between each loop
  -t, --ontop                      Stay on top (does not daemonize)
      --instances=NUM              Allow multiple instances to run simultaneously? 0 for infinite. default: 1
      --logdir=LOGDIR              Logfile to log to
      --logfile LOGFILE            Logfile to log to
      --loglevel LOGLEVEL          Log level defaults to DEBUG
      --logprefix=TRUE_OR_FALSE    All output to logfiles will be prefixed with PID and date/time.
      --pid_file PIDFILE           Directory to put pidfile
  -h, --help                       Show this message

== BUGS:

ICanDaemonize attempts to capture all STDOUT or STDERR and prepend that output with a timestamp and PID.
This appears to not be working right as most output lines also have the PID/timestamp at the end of the line as well.
I don't like how this was implemented anyway. Feels dirty.

== LICENSE:

(The MIT License)

Copyright (c) 2008 FIXME full name

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.