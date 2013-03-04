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
    # Delegate to ApiResponseCacher#get
    super
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
