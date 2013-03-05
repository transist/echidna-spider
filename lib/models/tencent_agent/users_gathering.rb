class TencentAgent
  module UsersGathering
    extend ActiveSupport::Concern

    KEYWORDS_QUEUE = 'spider:tencent:users_gathering:keywords_queue'

    def gather_users
      $redis.sunionstore(KEYWORDS_QUEUE, :words) unless $redis.exists(KEYWORDS_QUEUE)

      $logger.notice log('Gathering users...')

      while keyword = $redis.srandmember(KEYWORDS_QUEUE)
        $logger.notice log(%{Gathering first user from tweets of keyword "#{keyword}"...})
        result = cached_get('api/search/t', keyword: keyword, pagesize: 30)

        if result['ret'].zero?
          $redis.srem(KEYWORDS_QUEUE, keyword)

          unless result['data']
            $logger.notice log(%{No results for keyword "#{keyword}"})
            next
          end

          try_publish_user(result['data']['info'].first['name'])

        else
          $logger.err log("Failed to gather user: #{result['msg']}")
          break
        end
      end
      $logger.notice log('Finished users gathering')

    rescue Error => e
      $logger.err log("Aborted users gathering: #{e.message}")
    end

    private

    def try_publish_user(user_name)
      result = cached_get('api/user/other_info', name: user_name)

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
      $redis.rpush 'streaming/messages', {
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
      $redis.rpush 'streaming/messages', {
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
