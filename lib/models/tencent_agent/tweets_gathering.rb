require_relative 'users_gathering'

class TencentAgent
  module TweetsGathering
    extend ActiveSupport::Concern
    include UsersGathering

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
    rescue Error => e
      $logger.err log("Aborted tweets gathering: #{e.message}")
    end

    private

    def gather_tweets_since_latest_known_tweet
      # 70 is the max allowed value for reqnum
      get('api/statuses/home_timeline', reqnum: 70, pageflag: 2, pagetime: latest_tweet_timestamp)
    end

    def publish_tweets(tweets)
      tweets.each do |tweet|
        if try_publish_user(tweet['name'])
          $logger.notice log("Publishing tweet #{tweet['id']}")
          $redis.rpush "streaming/messages", {
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
        else
          $logger.warning log(%{Skip tweet "#{tweet['id']}" due to publish it's user skipped/failed})
        end
      end

      update_attribute(:latest_tweet_timestamp, tweets.first['timestamp'])
    end
  end
end
