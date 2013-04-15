require_relative 'users_gathering'

class TencentAgent
  module TweetsGathering
    extend ActiveSupport::Concern
    include UsersTracking

    def gather_tweets
      users_tracking_lists.each do |list_id, latest_tweet_timestamp|
        gather_tweets_from_list(list_id, latest_tweet_timestamp)
      end

      $logger.info log('Finished tweets gathering')
    rescue Error => e
      $logger.error log("Aborted tweets gathering: #{e.message}")
    rescue => e
      log_unexpected_error(e)
    end

    private

    def gather_tweets_from_list(list_id, latest_tweet_timestamp)
      if ENV['ECHIDNA_SPIDER_DEBUG'] == 'true'
        latest_tweet_timestamp = 2.days.ago.to_i
      else
        latest_tweet_timestamp = latest_tweet_timestamp.blank? ? 2.days.ago.to_i : latest_tweet_timestamp
      end

      $logger.info log("Gathering tweets from list #{list_id} since #{Time.at(latest_tweet_timestamp.to_i)}...")

      loop do
        result = gather_tweets_since_latest_known_tweet(list_id, latest_tweet_timestamp)

        if result['ret'].to_i.zero?
          unless result['data']
            $logger.info log('No new tweets (when ret code is zero)')
            break
          end

          latest_tweet_timestamp = publish_tweets(result['data']['info'], list_id, latest_tweet_timestamp)
          break if result['data']['hasnext'].zero?

        elsif result['ret'].to_i == 5 && result['errcode'].to_i == 5
          $logger.info log('No new tweets')
          break

        else
          $logger.error log("Failed to gather tweets: #{result['msg']}")

          break
        end

        sleep 5
      end
    end

    def gather_tweets_since_latest_known_tweet(list_id, latest_tweet_timestamp)
      # 70 is the max allowed value for reqnum
      get('api/list/timeline', listid: list_id, reqnum: 70, pageflag: 2, pagetime: latest_tweet_timestamp)
    end

    def publish_tweets(tweets, list_id, latest_tweet_timestamp)
      return latest_tweet_timestamp if tweets.blank?

      $logger.info log("Publishing tweets since #{Time.at(latest_tweet_timestamp.to_i)}")
      tweets.each do |tweet|
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

      $redis.hset users_tracking_lists_key, list_id, tweets.first['timestamp']
      tweets.first['timestamp']
    end
  end
end
