class WeiWatchersClient

  include HttpClient
  base_uri "#{ENV['WEI_WATCHERS_URL']}/api/"

  def self.enabled?
    ENV['WEI_WATCHERS_URL'].present?
  end

  def create_subscription(options = {})
    hashie_post('/event_subscriptions', {
      account: options[:account],
      endAt: (options[:endAt] || options[:end_at]).to_i.to_s,
      topics: options[:topics],
    }.compact)
  end


  private

  def http_client_auth_params
    {
      password: ENV['WEI_WATCHERS_PASSWORD'],
      username: ENV['WEI_WATCHERS_USERNAME'],
    }
  end

end
