class TencentAgent
  module ApiCallsLimiter
    extend ActiveSupport::Concern

    API_CALLS_COUNT_KEY = 'agents/tencent/api_calls_count'

    included do
      class Tencent::Weibo::AccessToken
        def request_with_conform_calls_limitation(*args, &block)
          if TencentAgent.limitation_reached?
            TencentAgent.schedule_reset_api_calls_count
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
      def schedule_reset_api_calls_count
        return if @api_calls_count_reset_scheduled

        seconds_before_next_reset = (1.hour.from_now.beginning_of_hour - Time.now).ceil

        EM::Synchrony.add_periodic_timer(seconds_before_next_reset) do
          TencentAgent.reset_api_calls_count
        end
        @api_calls_count_reset_scheduled = true
      end

      def reset_api_calls_count
        $redis.set(API_CALLS_COUNT_KEY, 0)
        @api_calls_count_reset_scheduled = false
        $logger.info 'Reset Tencent Weibo API calls count'
      end

      def limitation_reached?
        $redis.get(API_CALLS_COUNT_KEY).to_i >= 1000
      end
    end
  end
end
