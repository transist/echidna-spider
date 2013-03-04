class TencentAgent
  module TweetsGathering
    extend ActiveSupport::Concern

    GET_GROUP_IDS_URL = "http://#{ENV['ECHIDNA_STREAMING_IP']}:#{ENV['ECHIDNA_STREAMING_PORT']}/get_group_ids"

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
      access_token.get(
        'api/statuses/home_timeline', params:{reqnum: 70, pageflag: 2, pagetime: latest_tweet_timestamp}
      ).parsed
    end

    def publish_tweets(tweets)
      tweets.each do |tweet|
        if try_publish_user(tweet['name'])
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
        else
          $logger.warning log(%{Skip tweet "#{tweet['id']}" due to publish it's user skipped/failed})
        end
      end

      update_attribute(:latest_tweet_timestamp, tweets.first['timestamp'])
    end

    def try_publish_user(user_name)
      result = access_token.get('api/user/other_info', params:{name: user_name}).parsed

      if result['ret'].zero? && result['data']
        user = UserFilter.filter(result['data'])

        if user
          group_ids = get_group_ids(user)

          unless group_ids.empty?
            publish_user(user)
            group_ids.each do |group_id|
              publish_user_to_group(user, group_id)
            end
            return true
          end
        else
          $logger.notice log(%{Skip invalid user "#{user_name}"})
        end

      else
        $logger.err log(%{Failed to gather profile of user "#{user_name}"})
      end
      false
    end

    def publish_user(user)
      $logger.notice log(%{Publishing user "#{user['name']}"})
      $redis.lpush "streaming/messages", {
        type: "add_user",
        body: {
          id: user['name'],
          type: 'tencent',
          birth_year: user['birth_year'],
          gender: user['gender'],
          city: user['city']
        }
      }.to_json
    end

    def get_group_ids(user)
      response = Faraday.get(
        GET_GROUP_IDS_URL,
        birth_year: user['birth_year'],
        city: user['city'],
        gender: user['gender']
      )
      MultiJson.load(response.body)['ids']
    rescue
      $logger.err log(%{Failed to get group ids for user "#{user['name']}"})
      []
    end

    def publish_user_to_group(user, group_id)
      $logger.notice log(%{Publishing user "#{user['name']}" to group "#{group_id}"})
      $redis.lpush "streaming/messages", {
        type: "add_user_to_group",
        body: {
          group_id: group_id,
          user_id: user['name'],
          user_type: 'tencent'
        }
      }.to_json
    end
  end
end
