require 'spec_helper'

describe TencentAgent do
  let(:token_hash) {
    {
      openid: '1234567890',
      name: 'rainuxluo',
      nick: 'Rainux',
      state: '',
      access_token: 'access_token_value',
      refresh_token: 'refresh_token_value',
      expires_at: '1362467251'
    }
  }
  let(:agent) { TencentAgent.new(token_hash) }

  describe '#key' do
    subject { TencentAgent.new(openid: '123456789042') }
    its(:key) { should == 'agents/tencent/123456789042' }
  end
end
