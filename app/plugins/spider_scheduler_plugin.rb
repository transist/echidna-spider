require 'syslog'

class SpiderSchedulerPlugin
  def initialize(port, config, status, logger)
  end

  def run
    schedule_gather_tweets
  end

  private

  def schedule_gather_tweets
    EM::Synchrony.add_periodic_timer(5) do
      TencentAgent.all.each do |agent|

        operation = -> {
          agent.gather_tweets
        }

        operation.call
        EM.defer(operation)
      end
    end
  end
end
