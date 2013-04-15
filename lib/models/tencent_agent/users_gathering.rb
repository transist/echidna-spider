require_relative 'users_tracking'

class TencentAgent
  module UsersGathering
    extend ActiveSupport::Concern
    include UsersTracking

    GET_GROUP_IDS_URL = -> { "http://#{ENV['ECHIDNA_STREAMING_IP']}:#{ENV['ECHIDNA_STREAMING_PORT']}/get_group_ids" }

    KEYWORDS_QUEUE = 'spider:tencent:users_gathering:keywords_queue'
    SAMPLE_USERS = 'spider:tencent:users_gathering:sample_users'
    SAMPLE_USER_KEYWORDS = 'spider:tencent:users_gathering:sample_user:%s:keywords'

    def gather_users
      $redis.sunionstore(KEYWORDS_QUEUE, :words) unless $redis.exists(KEYWORDS_QUEUE)
      $logger.info log('Gathering users...')

      while keyword = $redis.srandmember(KEYWORDS_QUEUE)
        $logger.info log(%{Gathering first user from tweets of keyword "#{keyword}"...})
        result = cached_get('api/search/t', keyword: keyword, pagesize: 30)

        if result['ret'].to_i.zero?

          unless result['data']
            $logger.info log(%{No results for keyword "#{keyword}"})
            next
          end

          user_name = result['data']['info'].first['name']

          if sample_user(user_name, keyword)
            record_user_sample(user_name, keyword)
            $redis.rpush(UsersTracking::USERS_TRACKING_QUEUE, user_name)
            $redis.srem(KEYWORDS_QUEUE, keyword)
          end

        else
          $logger.error log("Failed to gather user: #{result['msg']}")
          break
        end

        sleep 5
      end

      if $redis.scard(KEYWORDS_QUEUE).zero?
        $logger.warn log('No more keywords in queue for users gathering')
      end

      $logger.info log('Finished users gathering')

    rescue Error => e
      $logger.error log("Aborted users gathering: #{e.message}")
    rescue => e
      log_unexpected_error(e)
    end

    private

    def record_user_sample(user_name, keyword)
      existing_score = $redis.zscore(SAMPLE_USERS, user_name).to_i
      $redis.zadd(SAMPLE_USERS, existing_score + 1, user_name)

      $redis.sadd(SAMPLE_USER_KEYWORDS % user_name, keyword)
    end

    def sample_user(user_name, keyword = nil)
      result = cached_get('api/user/other_info', name: user_name)

      if result['ret'].to_i.zero? && result['data']
        user = UserDecorator.decorate(result['data'])

        group_ids = get_group_ids(user)

        unless group_ids.empty?
          publish_user(user)
          group_ids.each do |group_id|
            publish_user_to_group(user, group_id)
          end
          return true
        end

      else
        $logger.error log(%{Failed to gather profile of user "#{user_name}"})
      end
      false
    end

    def publish_user(user)
      $logger.info log(%{Publishing user "#{user['name']}"})
      $redis.lpush 'streaming/messages', {
        type: 'add_user',
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
        GET_GROUP_IDS_URL.call,
        birth_year: user['birth_year'],
        city: user['city'],
        gender: user['gender']
      )
      MultiJson.load(response.body)['ids']
    rescue
      $logger.error log(%{Failed to get group ids for user "#{user['name']}"})
      []
    end

    def publish_user_to_group(user, group_id)
      $logger.info log(%{Publishing user "#{user['name']}" to group "#{group_id}"})
      $redis.lpush 'streaming/messages', {
        type: 'add_user_to_group',
        body: {
          group_id: group_id,
          user_id: user['name'],
          user_type: 'tencent'
        }
      }.to_json
    end
  end
end
