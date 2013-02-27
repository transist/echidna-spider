class SpiderAPI < Grape::API
  format :json

  helpers do
    def weibo
      @weibo ||= Tencent::Weibo::Client.new(
        ENV['ECHIDNA_SPIDER_TENCENT_APP_KEY'], ENV['ECHIDNA_SPIDER_TENCENT_APP_SECRET'],
        ENV['ECHIDNA_SPIDER_TENCENT_REDIRECT_URI']
      )
    end
  end

  resource :agents do
    resource :tencent do
      desc 'Register a new agent.'
      get :new do
        {authorize_url: weibo.auth_code.authorize_url}
      end

      desc 'Callback for Tencent Weibo API to actually create the agent.'
      get :create do
        begin
          TencentAgent.create(weibo.auth_code.get_token(params[:code]).to_hash.symbolize_keys)
          {success: true}
        rescue => e
          {success: false, error: e.message}
        end
      end
    end
  end
end
