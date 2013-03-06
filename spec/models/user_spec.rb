require 'spec_helper'
require "cancan/matchers"

describe User do
  describe 'abilities' do
    subject  { ability }
    let (:ability) { Ability.new(user) }
    let (:user) { nil }
    context 'when is an administrator' do
      let (:user) { FactoryGirl.build(:admin) }

      it { should be_able_to(:manage, User) }
      it { should be_able_to(:manage, LightweightActivity) }
      it { should be_able_to(:manage, InteractivePage) }
    end

    context 'when is an author' do
      pending 'not yet defined'
    end

    context 'when is a user' do
      pending 'not yet defined'
    end

    context 'when is anonymous' do
      let (:user) { FactoryGirl.build(:user) }

      it { should_not be_able_to(:manage, User) }
      it { should_not be_able_to(:read, LightweightActivity) }
      it { should_not be_able_to(:update, LightweightActivity) }
      it { should_not be_able_to(:create, LightweightActivity) }
    end
  end
end
