class TencentAgent
  module UsersTracking
    extend ActiveSupport::Concern

    USERS_TRACKING_LIST_PREFIX = 'UTL'
    USERS_TRACKING_LISTS_PATTERN = 'spider:tencent:%s:users_tracking_lists'
    USERS_TRACKING_QUEUE = 'spider:tencent:users_tracking_queue'

    def track_users
      $logger.info log('Tracking users...')

      # Tencent Weibo's add_to_list API accept at most 8 user names per request.
      loop do
        user_names = nil
        $redis.multi do
          user_names = $redis.lrange(USERS_TRACKING_QUEUE, 0, 7)
          $redis.ltrim(USERS_TRACKING_QUEUE, 8, -1)
        end

        if user_names.value.empty?
          break

        else
          begin
            track_users_by_list(user_names.value)
          rescue
            $redis.lpush(USERS_TRACKING_QUEUE, user_names.value)
            raise
          end

          sleep 5
        end
      end

      $logger.info log('Finished users tracking')
    rescue Error => e
      $logger.error log("Aborted users tracking: #{e.message}")
    rescue => e
      log_unexpected_error(e)
    end

    # A hash which key is the created list id, value is the latest_tweet_timestamp.
    def users_tracking_lists
      $redis.hgetall users_tracking_lists_key
    end

    def reset_users_tracking_lists
      $redis.hdel key, :latest_users_tracking_list_id
      $redis.del users_tracking_lists_key
    end

    private

    def users_tracking_lists_key
      USERS_TRACKING_LISTS_PATTERN % openid
    end

    def latest_users_tracking_list_id
      @attributes[:latest_users_tracking_list_id] || create_list(next_users_tracking_list_name)['listid']
    end

    def next_users_tracking_list_name
      # Humanized 1 based name sequence
      # The maximized allowd name length is 13
      '%s_%09d' % [USERS_TRACKING_LIST_PREFIX, $redis.hlen(users_tracking_lists_key) + 1]
    end

    def create_list(list_name)
      result = post('api/list/create', name: list_name, access: 1)
      if result['ret'].to_i.zero?
        add_list_to_users_tracking_lists(result['data'])
        $logger.info log(%{Created list "#{list_name}"})
        result['data']

      elsif result['ret'].to_i == 4 and result['errcode'].to_i == 98
        update_attribute :full_with_lists, true
        raise Error, 'List create limitation reached'

      else
        raise Error.new(%{Failed to create list "#{list_name}"}, result)
      end
    end

    def add_list_to_users_tracking_lists(list)
      $redis.hset users_tracking_lists_key, list['listid'], nil
      update_attribute :latest_users_tracking_list_id, list['listid']
    end

    def track_users_by_list(user_names)
      result = post('api/list/add_to_list', names: user_names.join(','), listid: latest_users_tracking_list_id)
      if result['ret'].to_i.zero?
        $logger.info log(%{Tracked users "#{user_names.join(',')}" by list})

      else
        # List limitation of maximized members reached
        if result['ret'].to_i == 5 and result['errcode'].to_i == 98
          create_list(next_users_tracking_list_name)
        end

        raise Error.new(%{Failed to track users "#{user_names.join(',')}" by list}, result)
      end
    end
  end
end
