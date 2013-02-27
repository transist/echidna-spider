class TencentAgent
  include RedisModel

  def key
    @key ||= "agents/tencent/#{@attributes[:openid]}"
  end

  def fetch
    @attributes[:latest_tweet_timestamp] ||= 2.days.ago.to_i

    $logger.notice log('Fetching tweets...')
    loop do
      result = fetch_tweets_since_latest_known_tweet

      if result['ret'].zero?
        unless result['data']
          $logger.notice log('No new tweets')
          break
        end

        publish_tweets(result['data']['info'])
        break unless result['data']['hasnext'].zero?

      else
        $logger.err log("Failed to fetch tweets: #{result['msg']}")

        break
      end
    end
    $logger.notice log('Finished tweets fetching')
  end

  private

  def access_token
    @weibo ||= Tencent::Weibo::Client.new(
      ENV['ECHIDNA_SPIDER_TENCENT_APP_KEY'], ENV['ECHIDNA_SPIDER_TENCENT_APP_SECRET'],
      ENV['ECHIDNA_SPIDER_TENCENT_REDIRECT_URI']
    )
    @access_token ||= Tencent::Weibo::AccessToken.from_hash(@weibo, attributes)
  end

  def fetch_tweets_since_latest_known_tweet
    # 70 is the max allowed value for reqnum
    access_token.get(
      'api/statuses/home_timeline', params:{reqnum: 70, pageflag: 2, pagetime: latest_tweet_timestamp}
    ).parsed
  end

  def publish_tweets(tweets)
    tweets.each do |tweet|
      $logger.notice log("Publishing tweet #{tweet['id']}")
      $redis.publish :add_tweet, {
        user_id: tweet['name'],
        user_type: :tencent,
        text: tweet['text'],
        id: tweet['id'],
        url: "http://t.qq.com/p/t/#{tweet['id']}",
        timestamp: tweet['timestamp']
      }.to_json
    end

    update_attribute(:latest_tweet_timestamp, tweets.first['timestamp'])
  end

  def log(message)
    "Tencent Weibo agent #{name}: #{message}"
  end
end
