class TencentAgent
  module UsersTracking
    extend ActiveSupport::Concern

    USERS_TRACKING_LIST = 'TrackingUsers'
    USERS_TRACKING_QUEUE = 'spider:tencent:users_tracking_queue'

    def track_users
      $logger.notice log('Tracking users...')

      # Tencent Weibo's add_to_list API accept at most 8 user names per request.
      while user_names = $redis.lrange(USERS_TRACKING_QUEUE, 0, 7) and !user_names.empty?
        if track_users_by_list(user_names)
          $redis.ltrim(USERS_TRACKING_QUEUE, user_names.size, -1)
        end

        sleep 5
      end

      $logger.notice log('Finished users tracking')
    rescue Error => e
      $logger.err log("Aborted users tracking: #{e.message}")
    rescue => e
      $logger.err log(%{Unexpect error: %s\n%s} % [e.inspect, e.backtrace.join("\n")])
    end

    def tracking_list_id
      @tracking_list_id ||=
        begin
          result = post('api/list/get_list')

          if result['ret'].to_i.zero?
            list = result['data']['info'].find {|list| list['name'] == USERS_TRACKING_LIST }
            list = create_list(USERS_TRACKING_LIST) unless list

          elsif result['ret'].to_i == 1 && result['errcode'].to_i == 44
            # Tencent API treat the case agent don't have any list yet as
            # error, and return this error code combination.
            list = create_list(USERS_TRACKING_LIST)
          else
            raise Error, "Failed to get list: #{result['msg']}"
          end

          list['listid']
        end
    end

    private

    def create_list(list_name)
      result = post('api/list/create', name: list_name, access: 1)
      if result['ret'].to_i.zero?
        $logger.notice log(%{Created list "#{list_name}"})
        result['data']
      else
        raise Error, %{Failed to create list "#{list_name}": #{result['msg']}}
      end
    end

    def track_users_by_list(user_names)
      result = post('api/list/add_to_list', names: user_names.join(','), listid: tracking_list_id)
      if result['ret'].to_i.zero?
        $logger.notice log(%{Tracked users "#{user_names.join(',')}" by list})
        true
      else
        $logger.err log(%{Failed to track users "#{user_names.join(',')}" by list: #{result['msg']}})
        false
      end
    end
  end
end
