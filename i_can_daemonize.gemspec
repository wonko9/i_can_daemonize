# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{i_can_daemonize}
  s.version = "0.7.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Adam Pisoni", "Amos Elliston"]
  s.date = %q{2009-06-15}
  s.description = %q{ICanDaemonize makes it dead simple to create daemons of your own}
  s.email = %q{wonko9@gmail.com}
  s.files = ["History.txt", "Manifest.txt", "Rakefile", "README.txt", "VERSION.yml", "lib/i_can_daemonize.rb", "test/simple_daemon.rb", "test/test_helper.rb", "test/test_i_can_daemonize.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/wonko9/i_can_daemonize}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{ICanDaemonize makes it dead simple to create daemons of your own}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
