ENV['ECHIDNA_ENV'] = 'test'

require 'bundler'
Bundler.require(:default, :test)

RSpec.configure do |config|

  def flush_redis
    $redis.keys('*').each do |key|
      $redis.del key
    end
  end

  config.before(:all) do
    flush_redis
  end
end
