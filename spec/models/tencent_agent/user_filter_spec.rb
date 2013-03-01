require 'spec_helper'

describe TencentAgent::UserFilter do
  let(:user) {
    {
      'name' => 'rainuxluo',
      'birth_year' => 1983,
      'province_code' => '51',
      'city_code' => '1',
      'sex' => 1
    }
  }

  describe '.filter' do
    context 'when user is valid' do
      it 'return user with transformed fields' do
        subject.filter(user)
        expect(user).to include('city' => '成都')
        expect(user).to include('gender' => 'male')
      end
    end

    context 'when user is invalid' do
      context 'lack province_code' do
        it 'should return nil' do
          user['province_code'] = ''
          expect(subject.filter(user)).to be_nil
        end
      end

      context 'lack city_code' do
        it 'should return nil' do
          user['city_code'] = ''
          expect(subject.filter(user)).to be_nil
        end
      end

      context 'lack sex' do
        it 'should return nil' do
          user['sex'] = 0
          expect(subject.filter(user)).to be_nil
        end
      end

      context 'lack birth_year' do
        it 'should return nil' do
          user['birth_year'] = 0
          expect(subject.filter(user)).to be_nil
        end
      end
    end
  end

  describe '.filter_by_city' do
    context 'when lack province_code' do
      it 'should return nil' do
        user['province_code'] = '0'
        expect(subject.send(:filter_by_city, user)).to be_nil

        user['province_code'] = ''
        expect(subject.send(:filter_by_city, user)).to be_nil

        user['province_code'] = 0
        expect(subject.send(:filter_by_city, user)).to be_nil
      end
    end

    context 'when province_code is in special cities' do
      it 'should set city field to the special city name' do
        {
          '11' => '北京',
          '12' => '天津',
          '31' => '上海',
          '50' => '重庆'
        }.each do |code, city|
          user['province_code'] = code
          subject.send(:filter_by_city, user)
          expect(user['city']).to eq(city)
        end
      end
    end

    context 'when province_code is not in special cities' do
      context 'when lack city_code' do
        it 'should return nil' do
          user['city_code'] = '0'
          expect(subject.send(:filter_by_city, user)).to be_nil

          user['city_code'] = ''
          expect(subject.send(:filter_by_city, user)).to be_nil

          user['city_code'] = 0
          expect(subject.send(:filter_by_city, user)).to be_nil
        end
      end

      context 'when has city_code' do
        it 'should set city field to the corresponding city name' do
          subject.send(:filter_by_city, user)
          expect(user['city']).to eq('成都')
        end
      end
    end
  end

  describe '.filter_by_gender' do
    context 'when lack sex' do
      it 'should return nil' do
        user['sex'] = 0
        expect(subject.send(:filter_by_gender, user)).to be_nil
      end
    end

    context 'when has sex' do
      it 'should set gender field to "male" or "female"' do
        {
          1 => 'male',
          2 => 'female'
        }.each do |sex, gender|
          user['sex'] = sex
          subject.send(:filter_by_gender, user)
          expect(user['gender']).to eq(gender)
        end
      end
    end
  end
end
