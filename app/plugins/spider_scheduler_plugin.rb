class SpiderSchedulerPlugin
  def initialize(port, config, status, logger)
  end

  def run
    schedule_gather_users
    schedule_track_users
    schedule_gather_tweets
  end

  private

  def schedule_gather_tweets
    gather_tweets_operation = -> {
      # Agents will do their work concurrently
      TencentAgent.all.each do |agent|

        operation = -> {
          agent.gather_tweets
        }

        EM::Synchrony.defer(operation)
      end
    }

    EM::Synchrony.add_periodic_timer(30, &gather_tweets_operation)

    # Run gather_tweets_operation immediately for after boot
    gather_tweets_operation.call
  end

  def schedule_gather_users
    gather_users_operation = -> {
      TencentAgent.all.each do |agent|

        operation = -> {
          agent.gather_users
        }

        EM::Synchrony.defer(operation)
      end
    }

    EM::Synchrony.add_periodic_timer(10.minutes, &gather_users_operation)
    gather_users_operation.call
  end

  def schedule_track_users
    track_users_operation = -> {
      TencentAgent.all.each do |agent|

        operation = -> {
          agent.track_users
        }

        EM::Synchrony.defer(operation)
      end
    }

    EM::Synchrony.add_periodic_timer(5.minutes, &track_users_operation)
    track_users_operation.call
  end
end
