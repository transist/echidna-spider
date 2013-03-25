require 'spec_helper'

describe TencentAgent::UserDecorator do
  let(:user) {
    {
      'name' => 'rainuxluo',
      'birth_year' => 1983,
      'province_code' => '51',
      'city_code' => '1',
      'sex' => 1
    }
  }

  describe '.decorate' do
    context 'when user is valid' do
      it 'return user with transformed fields' do
        subject.decorate(user)
        expect(user).to include('city' => '成都')
        expect(user).to include('gender' => 'male')
      end
    end
  end

  describe '.decorate_city' do
    context 'when province_code is in special cities' do
      it 'should set city field to the special city name' do
        {
          '11' => '北京',
          '12' => '天津',
          '31' => '上海',
          '50' => '重庆'
        }.each do |code, city|
          user['province_code'] = code
          subject.send(:decorate_city, user)
          expect(user['city']).to eq(city)
        end
      end
    end

    context 'when province_code is not in special cities' do
      context 'when has city_code' do
        it 'should set city field to the corresponding city name' do
          subject.send(:decorate_city, user)
          expect(user['city']).to eq('成都')
        end
      end
    end
  end

  describe '.decorate_gender' do
    context 'when lack sex' do
      it 'should set gender field to "both"' do
        user['sex'] = 0
        expect(subject.send(:decorate_gender, user)).to include('gender' => 'both')
      end
    end

    context 'when has sex' do
      it 'should set gender field to "male" or "female"' do
        {
          1 => 'male',
          2 => 'female'
        }.each do |sex, gender|
          user['sex'] = sex
          subject.send(:decorate_gender, user)
          expect(user['gender']).to eq(gender)
        end
      end
    end
  end
end
