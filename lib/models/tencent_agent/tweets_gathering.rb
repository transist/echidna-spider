require_relative 'users_gathering'

class TencentAgent
  module TweetsGathering
    extend ActiveSupport::Concern
    include UsersTracking

    def gather_tweets
      if ENV['ECHIDNA_SPIDER_DEBUG'] == 'true'
        @attributes[:latest_tweet_timestamp] = 2.days.ago.to_i
      else
        @attributes[:latest_tweet_timestamp] ||= 2.days.ago.to_i
      end

      $logger.notice log('Gathering tweets...')
      loop do
        result = gather_tweets_since_latest_known_tweet

        if result['ret'].to_i.zero?
          unless result['data']
            $logger.notice log('No new tweets (when ret code is zero)')
            break
          end

          publish_tweets(result['data']['info'])
          break if result['data']['hasnext'].zero?

        elsif result['ret'].to_i == 5 && result['errcode'].to_i == 5
          $logger.notice log('No new tweets')
          break

        else
          $logger.err log("Failed to gather tweets: #{result['msg']}")

          break
        end

        sleep 5
      end
      $logger.notice log('Finished tweets gathering')
    rescue Error => e
      $logger.err log("Aborted tweets gathering: #{e.message}")
    end

    private

    def gather_tweets_since_latest_known_tweet
      # 70 is the max allowed value for reqnum
      get('api/list/timeline', listid: tracking_list_id, reqnum: 70, pageflag: 2, pagetime: latest_tweet_timestamp)
    end

    def publish_tweets(tweets)
      return if tweets.blank?
      tweets.each do |tweet|
        $logger.notice log("Publishing tweet #{tweet['id']}")
        $redis.lpush "streaming/messages", {
          type: "add_tweet",
          body: {
            user_id: tweet['name'],
            user_type: :tencent,
            text: tweet['text'],
            id: tweet['id'],
            url: "http://t.qq.com/p/t/#{tweet['id']}",
          timestamp: tweet['timestamp']
          }
        }.to_json
      end

      update_attribute(:latest_tweet_timestamp, tweets.first['timestamp'])
    end
  end
end
