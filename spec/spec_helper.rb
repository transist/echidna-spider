ENV['ECHIDNA_SPIDER_ENV'] ||= 'test'
ENV['ECHIDNA_REDIS_HOST'] ||= '127.0.0.1'
ENV['ECHIDNA_REDIS_PORT'] ||= '6379'
ENV['ECHIDNA_REDIS_NAMESPACE'] ||= 'e:t'

require 'bundler'
Bundler.require(:default, ENV['ECHIDNA_SPIDER_ENV'].to_sym)

%w(config/initializers/*.rb lib/redis/**/*.rb lib/**/*.rb app/apis/*.rb).each do |dir|
  Dir[dir].each {|file| require_relative File.join('..', file) }
end

$redis = Redis::Namespace.new(
  ENV['ECHIDNA_REDIS_NAMESPACE'],
  redis: SymbolizedRedis.new(
    host: ENV['ECHIDNA_REDIS_HOST'], port: ENV['ECHIDNA_REDIS_PORT'], driver: :hiredis
  )
)

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
