class TencentAgent
  module UsersGathering
    extend ActiveSupport::Concern
    include TweetsGathering

    KEYWORDS_QUEUE = 'spider:tencent:users_gathering:keywords_queue'

    def gather_users
      $redis.sunionstore(KEYWORDS_QUEUE, :words) unless $redis.exists(KEYWORDS_QUEUE)

      $logger.notice log('Gathering users...')

      while keyword = $redis.srandmember(KEYWORDS_QUEUE)
        $logger.notice log(%{Gathering first user from tweets of keyword "#{keyword}"...})
        result = access_token.get('api/search/t', params: {keyword: keyword, pagesize: 1}).parsed

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
  end
end
