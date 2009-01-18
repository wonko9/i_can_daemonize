Gem::Specification.new do |s|
  s.name     = "i_can_daemonize"
  s.version  = "0.3.0"
  s.date     = "2009-01-15"
  s.summary  = "Better way to build daemons"
  s.email    = "apisoni@yammer-inc.com"
  s.homepage = "http://github.com/wonko9/i_can_daemonize"
  s.description = "Better daemonizer."
  s.has_rdoc = true
  s.authors  = ["Adam Pisoni", "Amos Elliston"]
  s.files    = [
  "History.txt", 
    "README.txt", 
    "Rakefile", 
    "i_can_daemonize.gemspec",
    "lib/i_can_daemonize.rb",
    "lib/i_can_daemonize/version.rb",
    "examples/feature_demo.rb",
    "examples/rails_daemon.rb",
    "examples/simple_daemon.rb",
    "examples/starling_queue_daemon.rb",
  ]

  s.test_files = ["test/test_i_can_daemonize.rb"]
  s.rdoc_options = ["--main", "README.txt"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
#  s.add_dependency("diff-lcs", ["> 0.0.0"])
end

