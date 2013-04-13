class SpiderSchedulerPlugin
  def initialize(port, config, status, logger)
    @scheduler = Rufus::Scheduler.start_new
  end

  def run
    schedule_refresh_access_token
    schedule_gather_users
    schedule_track_users
    schedule_gather_tweets
  end

  private

  def schedule_gather_tweets
    @scheduler.every '30s', first_in: '0s', mutex: :gather_tweets do
      TencentAgent.all.each do |agent|
        agent.gather_tweets
      end
    end
  end

  def schedule_gather_users
    @scheduler.every '10m', first_in: '0s', mutex: :gather_users do
      TencentAgent.all.each do |agent|
        agent.gather_users
      end
    end
  end

  def schedule_track_users
    @scheduler.every '5m', first_in: '0s', mutex: :track_users do
      TencentAgent.all.each do |agent|
        agent.track_users
      end
    end
  end

  def schedule_refresh_access_token
    @scheduler.every '1d', first_in: '0s', mutex:
      [:gather_users, :track_users, :gather_tweets] do
      TencentAgent.all.each do |agent|
        agent.refresh_access_token
      end
    end
  end
end
