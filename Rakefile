require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rcov/rcovtask'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "i_can_daemonize"
    s.summary = "ICanDaemonize makes it dead simple to create daemons of your own"
    s.email = "wonko9@gmail.com"
    s.homepage = "http://github.com/wonko9/i_can_daemonize"
    s.description = "ICanDaemonize makes it dead simple to create daemons of your own"
    s.authors = ["Adam Pisoni", "Amos Elliston"]
    s.files =  FileList["[A-Z]*", "{lib,test}/**/*"]
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

Rake::TestTask.new

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'test'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

Rcov::RcovTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

task :default => :test
