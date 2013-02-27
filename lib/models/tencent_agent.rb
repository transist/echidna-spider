class TencentAgent
  include RedisModel

  def key
    @key ||= "agents/tencent/#{@attributes[:openid]}"
  end
end
