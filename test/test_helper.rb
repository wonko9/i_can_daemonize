require 'test/unit'
require 'pp'

TEST_FILE = File.dirname(__FILE__) + '/test.txt' unless defined?(TEST_FILE)

unless Test::Unit::TestCase.respond_to?(:test)
  class << Test::Unit::TestCase
    def test(name, &block)
      test_name = "test_#{name.gsub(/[\s\W]/,'_')}"
      raise ArgumentError, "#{test_name} is already defined" if self.instance_methods.include? test_name
      define_method test_name, &block
    end
  end
end
