require 'syslog'

class SpiderSchedulerPlugin
  def initialize(port, config, status, logger)
  end

  def run
    EM::Synchrony.add_periodic_timer(5) do
      TencentAgent.all.each do |agent|

        operation = -> {
          agent.fetch
        }

        operation.call
        EM.defer(operation)
      end
    end
  end
end
