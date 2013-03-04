class TencentAgent
  module ApiResponseCacher
    extend ActiveSupport::Concern

    CACHE_KEY = 'spider:tencent:api_cache'

    def get(path, params = {}, &block)
      cache_field = "GET #{path} #{params}"

      if $redis.hexists(CACHE_KEY, cache_field)
        $logger.notice log("Cache hit: #{cache_field}")
        MultiJson.load($redis.hget(CACHE_KEY, cache_field))

      else
        $logger.notice log("Cache miss: #{cache_field}")
        result = access_token.get(path, params: params, &block).parsed
        $redis.hset(CACHE_KEY, cache_field, MultiJson.dump(result))
        result
      end
    end
  end
end
