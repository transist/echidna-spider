ENV['ECHIDNA_SPIDER_ENV'] ||= 'development'
ENV['ECHIDNA_SPIDER_IP'] ||= '0.0.0.0'
ENV['ECHIDNA_SPIDER_PORT'] ||= '9000'
ENV['ECHIDNA_SPIDER_DAEMON'] ||= 'false'
ENV['ECHIDNA_SPIDER_APP_KEY'] ||= '801317572'
ENV['ECHIDNA_SPIDER_APP_SECRET'] ||= '2a7d8fc10f48f5dbacffed0cee5dc49e'
ENV['ECHIDNA_SPIDER_REDIRECT_URI'] ||= 'http://localhost:9000/agents/create'
ENV['ECHIDNA_REDIS_HOST'] ||= '127.0.0.1'
ENV['ECHIDNA_REDIS_PORT'] ||= '6379'
ENV['ECHIDNA_REDIS_NAMESPACE'] ||= 'e:d'

ARGV.replace(ARGV + ['-e', ENV['ECHIDNA_SPIDER_ENV'], '-a', ENV['ECHIDNA_SPIDER_IP'], '-p', ENV['ECHIDNA_SPIDER_PORT']])
ARGV << '-d' if ENV['ECHIDNA_SPIDER_DAEMON'] == 'true'

require 'bundler'
Bundler.require(:default, ENV['ECHIDNA_SPIDER_ENV'].to_sym)

%w(config/initializers/*.rb lib/redis/**/*.rb lib/**/*.rb app/apis/*.rb).each do |dir|
  Dir[dir].each {|file| require_relative file }
end

class Spider < Goliath::API
  def response(env)
    SpiderAPI.call(env)
  end
end
