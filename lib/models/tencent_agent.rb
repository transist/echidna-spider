class TencentAgent
  include RedisModel

  def key
    @key ||= "agents/tencent/#{@attributes[:openid]}"
  end

  def gather_tweets
    @attributes[:latest_tweet_timestamp] ||= 2.days.ago.to_i

    $logger.notice log('Gathering tweets...')
    loop do
      result = gather_tweets_since_latest_known_tweet

      if result['ret'].zero?
        unless result['data']
          $logger.notice log('No new tweets')
          break
        end

        publish_tweets(result['data']['info'])
        break unless result['data']['hasnext'].zero?

      else
        $logger.err log("Failed to gather tweets: #{result['msg']}")

        break
      end
    end
    $logger.notice log('Finished tweets gathering')
  end

  private

  def access_token
    @weibo ||= Tencent::Weibo::Client.new(
      ENV['ECHIDNA_SPIDER_TENCENT_APP_KEY'], ENV['ECHIDNA_SPIDER_TENCENT_APP_SECRET'],
      ENV['ECHIDNA_SPIDER_TENCENT_REDIRECT_URI']
    )
    @access_token ||= Tencent::Weibo::AccessToken.from_hash(@weibo, attributes)
  end

  def gather_tweets_since_latest_known_tweet
    # 70 is the max allowed value for reqnum
    access_token.get(
      'api/statuses/home_timeline', params:{reqnum: 70, pageflag: 2, pagetime: latest_tweet_timestamp}
    ).parsed
  end

  def publish_tweets(tweets)
    tweets.each do |tweet|
      if publish_user(tweet['name'])
        $logger.notice log("Publishing tweet #{tweet['id']}")
        $redis.publish :add_tweet, {
          user_id: tweet['name'],
          user_type: :tencent,
          text: tweet['text'],
          id: tweet['id'],
          url: "http://t.qq.com/p/t/#{tweet['id']}",
          timestamp: tweet['timestamp']
        }.to_json
      else
        $logger.warning log(%{Skip tweet "#{tweet['id']}" due to publish it's user skipped/failed})
      end
    end

    update_attribute(:latest_tweet_timestamp, tweets.first['timestamp'])
  end

  def publish_user(user_name)
    result = access_token.get('api/user/other_info', params:{name: user_name}).parsed

    if result['ret'].zero? && result['data']
      user = UserFilter.filter(result['data'])

      if user
        $logger.notice log(%{Publishing user "#{user['name']}"})
        $redis.publish :add_user, {
          id: user['name'],
          type: 'tencent',
          birth_year: user['birth_year'],
          gender: user['gender'],
          city: user['city']
        }.to_json

        return true
      else
        $logger.notice log(%{Skip invalid user "#{user_name}"})
      end

    else
      $logger.err log(%{Failed to gather profile of user "#{user_name}"})
    end
    false
  end

  def log(message)
    "Tencent Weibo agent #{name}: #{message}"
  end
end
