require 'spec_helper'

describe TencentAgent do
  describe '#key' do
    subject { TencentAgent.new(openid: '123456789042') }
    its(:key) { should == 'agents/tencent/123456789042' }
  end
end
