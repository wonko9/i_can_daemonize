require 'test/unit'
require 'pp'
require File.dirname(__FILE__) + '/../lib/i_can_daemonize'

TEST_FILE = File.dirname(__FILE__) + '/test.txt' unless defined?(TEST_FILE)

class << Test::Unit::TestCase
  def test(name, &block)
    test_name = "test_#{name.gsub(/[\s\W]/,'_')}"
    raise ArgumentError, "#{test_name} is already defined" if self.instance_methods.include? test_name
    define_method test_name, &block
  end
end
