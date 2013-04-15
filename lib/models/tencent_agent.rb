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
      $logger.info log('Refreshing access token...')
      new_token = access_token.refresh!
      TencentAgent.create(new_token.to_hash.symbolize_keys)
      $logger.info log('Finished access token refreshing')
    end
  rescue => e
    log_unexpected_error(e)
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

  # Log unexpected errors to a redis list
  def log_unexpected_error(exception)
    error = {
      class: exception.class.name,
      message: exception.message,
      backtrace: exception.backtrace,
      raised_at: Time.now
    }
    if exception.respond_to?(:response)
      faraday_response = exception.response.response.to_hash
      # Delete self-reference
      faraday_response.delete(:response)
      faraday_response[:url] = faraday_response[:url].to_s
      faraday_response[:body] = MultiJson.load(faraday_response[:body]) rescue faraday_response[:body]

      error[:response] = faraday_response
    end

    $redis.rpush :spider_errors, MultiJson.dump(error)
    $logger.warn %{Unexpected error "#{exception.inspect}" logged to redis}
  end
end
