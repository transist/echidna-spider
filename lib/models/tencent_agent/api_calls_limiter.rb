class TencentAgent
  module ApiCallsLimiter
    extend ActiveSupport::Concern

    API_CALLS_COUNT_KEY = 'agents/tencent/api_calls_count'

    included do
      class Tencent::Weibo::AccessToken
        def request_with_conform_calls_limitation(*args, &block)
          if TencentAgent.limitation_reached?
            raise Error, 'Tencent Weibo API calls limitation reached'
          else
            count = $redis.incr(API_CALLS_COUNT_KEY)
            $logger.info "Tencent Weibo API calls count: #{count}"
            request_without_conform_calls_limitation(*args, &block)
          end
        end

        alias_method_chain :request, :conform_calls_limitation
      end
    end

    module ClassMethods
      def reset_api_calls_count
        $redis.set(API_CALLS_COUNT_KEY, 0)
        $logger.info 'Reset Tencent Weibo API calls count'
      end

      def limitation_reached?
        $redis.get(API_CALLS_COUNT_KEY).to_i >= 1000
      end
    end
  end
end
