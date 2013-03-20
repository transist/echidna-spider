require_relative 'tencent_agent/api_calls_limiter'
require_relative 'tencent_agent/api_response_cacher'
require_relative 'tencent_agent/tweets_gathering'
require_relative 'tencent_agent/users_gathering'
require_relative 'tencent_agent/users_tracking'

class TencentAgent
  include RedisModel
  include TweetsGathering
  include UsersGathering
  include ApiCallsLimiter
  include ApiResponseCacher

  def key
    @key ||= "agents/tencent/#{@attributes[:openid]}"
  end

  def get(path, params = {}, &block)
    access_token.get(path, params: params, &block).parsed
  end

  def post(path, body = {}, &block)
    access_token.post(path, body: body, &block).parsed
  end

  def refresh_access_token
    if Time.at(expires_at.to_i) - Time.now <= 1.day
      $logger.notice log('Refreshing access token...')
      new_token = access_token.refresh!
      TencentAgent.create(new_token.to_hash.symbolize_keys)
      $logger.notice log('Finished access token refreshing')
    end
  rescue => e
    $logger.notice log("Failed to refresh access token: #{e.message}")
  end

  private

  def access_token
    @weibo ||= Tencent::Weibo::Client.new(
      ENV['ECHIDNA_SPIDER_TENCENT_APP_KEY'], ENV['ECHIDNA_SPIDER_TENCENT_APP_SECRET'],
      ENV['ECHIDNA_SPIDER_TENCENT_REDIRECT_URI']
    )
    @access_token ||= Tencent::Weibo::AccessToken.from_hash(@weibo, attributes)
  end

  def log(message)
    "Tencent Weibo agent #{name}: #{message}"
  end
end
