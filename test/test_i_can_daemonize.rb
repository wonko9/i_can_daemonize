require File.dirname(__FILE__) + '/test_helper.rb'

class TestICanDaemonize < Test::Unit::TestCase
  DEFAULT_LOG_FILE = File.dirname(__FILE__) + '/simple_daemon.log'

  def setup
    File.delete(TEST_FILE) if File.exist?(TEST_FILE)
    @daemon = "#{File.dirname(__FILE__)}/simple_daemon.rb"
  end

  def teardown
    File.delete(TEST_FILE) if File.exist?(TEST_FILE)
    File.delete(DEFAULT_LOG_FILE) if File.exist?(DEFAULT_LOG_FILE)
  end

  test "passing options" do
    log_file = File.expand_path(File.join(File.dirname(__FILE__), 'test.log'))
    pid_file = File.expand_path(File.join(File.dirname(__FILE__), 'test.pid'))
    `ruby #{@daemon} --log-file #{log_file} --pid-file #{pid_file} start`
    `ruby #{@daemon} --log-file #{log_file} --pid-file #{pid_file} stop`
    File.delete(log_file)
    assert_equal "#{log_file}|#{pid_file}", File.read(TEST_FILE)
  end
  
  test "loop every" do
    `ruby #{@daemon} --loop-every 1 start`
    sleep 5
    `ruby #{@daemon} stop`
    counter = File.read(TEST_FILE).to_i
    assert counter > 5
  end
  
  test "arg class macro" do
    `ruby #{@daemon} --test test -s short-test start`
    `ruby #{@daemon} stop`
    assert_equal "test|short-test", File.read(TEST_FILE)
  end

  test "delete stale pid" do
    pidfile = File.dirname(__FILE__) + '/testpids.pid'
    File.open(pidfile, 'w'){|f| f << '999999999'}
    `ruby #{@daemon} start --pid-file=#{pidfile}`
    `ruby #{@daemon} stop --pid-file=#{pidfile}`
    assert !File.exist?(pidfile)
  end

end
