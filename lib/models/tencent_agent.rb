class TencentAgent
  include RedisModel
  include TweetsGathering
  include UsersGathering
  include ApiCallsLimiter
  include ApiResponseCacher

  LIST_NAME = 'userlist'

  def key
    @key ||= "agents/tencent/#{@attributes[:openid]}"
  end

  def get(path, params = {}, &block)
    access_token.get(path, params: params, &block).parsed
  end

  def post(path, body = {}, &block)
    access_token.post(path, body: body, &block).parsed
  end

  private

  def access_token
    @weibo ||= Tencent::Weibo::Client.new(
      ENV['ECHIDNA_SPIDER_TENCENT_APP_KEY'], ENV['ECHIDNA_SPIDER_TENCENT_APP_SECRET'],
      ENV['ECHIDNA_SPIDER_TENCENT_REDIRECT_URI']
    )
    @access_token ||= Tencent::Weibo::AccessToken.from_hash(@weibo, attributes)
  end

  def log(message)
    "Tencent Weibo agent #{name}: #{message}"
  end

  def user_list
    @list ||= post('api/list/get_list')['data']['info'].map{|el| el if el['name'] == LIST_NAME }.compact.first
    @list ||= post('api/list/create', format: 'json', name: LIST_NAME, description: LIST_NAME, tag: 'echidna', access: '1')

    @list
  end

  def add_user_to_list username
    post('api/list/add_to_list', format: 'json',  names: username, listid: user_list['listid'])
  end
end
