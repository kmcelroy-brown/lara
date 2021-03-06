require 'spec_helper'
require "cancan/matchers"

describe User do
  # In production these would be defined in config/app_environment_variables.rb
  ENV['SSO_CLIENT_ID']                      ||= 'localhost'
  ENV['CONFIGURED_PORTALS']                 ||= 'LOCAL CONCORD_PORTAL' # First one is default
  ENV['CONCORD_LOCAL_URL']                  ||= 'http://localhost:9000'
  ENV['CONCORD_LOCAL_CLIENT_SECRET']        ||= 'abf0a91d-f761-499c-83a6-5816d5428d38'
  ENV['CONCORD_CONCORD_PORTAL_URL']         ||= ''
  ENV['CONCORD_CONCORD_PORTAL_CLIENT_SECRET'] ||= ''

  # Tests User authorization for various actions.
  describe 'abilities' do
    subject  { ability }
    let(:ability) { Ability.new(user) }
    let(:user) { nil }
    let(:locked_activity) do
      la = FactoryGirl.create(:locked_activity)
      la.pages << FactoryGirl.create(:page)
      la.user = FactoryGirl.create(:admin)
      la.save
      la
    end

    context 'when is an administrator' do
      let(:user) { FactoryGirl.build(:admin) }

      it { is_expected.to be_able_to(:manage, User) }
      it { is_expected.to be_able_to(:manage, Sequence) }
      it { is_expected.to be_able_to(:manage, LightweightActivity) }
      it { is_expected.to be_able_to(:manage, InteractivePage) }
      it { is_expected.to be_able_to(:manage, locked_activity) }
    end

    context 'when is an author' do
      let(:user) { FactoryGirl.build(:author) }
      let(:other_user) { FactoryGirl.build(:author) }
      let(:self_activity) { stub_model(LightweightActivity, :user_id => user.id) }
      let (:other_activity) do
        oa = FactoryGirl.create(:public_activity)
        oa.user = other_user
        oa.pages << FactoryGirl.create(:page)
        oa.save
        oa
      end
      let (:self_sequence) { stub_model(Sequence, :user_id => user.id) }
      let (:other_sequence) { stub_model(Sequence, :user_id => 15) }

      it { is_expected.to be_able_to(:create, Sequence) }
      it { is_expected.to be_able_to(:create, LightweightActivity) }
      it { is_expected.to be_able_to(:create, InteractivePage) }
      # Can edit activities, etc. which they own
      it { is_expected.to be_able_to(:update, self_sequence) }
      it { is_expected.not_to be_able_to(:update, other_sequence) }
      it { is_expected.to be_able_to(:update, self_activity) }
      it { is_expected.not_to be_able_to(:update, other_activity) }
      it { is_expected.to be_able_to(:read, other_activity) }
      it { is_expected.to be_able_to(:read, other_activity.pages.first) }
      it { is_expected.to be_able_to(:duplicate, other_activity) }
      # Can't edit locked activities
      it { is_expected.not_to be_able_to(:update, locked_activity) }
      it { is_expected.to be_able_to(:read, other_activity.pages.first) }
      it { is_expected.not_to be_able_to(:duplicate, locked_activity) }
    end

    context 'when is a user' do
      # pending 'currently same as anonymous'
    end

    context 'when is anonymous' do
      let(:user) { FactoryGirl.build(:user) }
      let(:other_user) { FactoryGirl.build(:author) }
      let(:hidden_activity) do
        act = FactoryGirl.create(:activity)
        act.user = other_user
        act.save
        act
      end
      let(:public_activity) do
        oa = FactoryGirl.create(:public_activity)
        oa.user = other_user
        oa.pages << FactoryGirl.create(:page)
        oa.save
        oa
      end

      it { is_expected.not_to be_able_to(:manage, User) }
      it { is_expected.not_to be_able_to(:update, LightweightActivity) }
      it { is_expected.not_to be_able_to(:create, LightweightActivity) }
      it { is_expected.to be_able_to(:read, Sequence) }
      it { is_expected.to be_able_to(:read, public_activity) }
      it { is_expected.to be_able_to(:read, hidden_activity) } # But it won't be in lists
    end
  end

  describe "#find_for_concord_portal_oauth" do
    let(:auth_email)    { "testuser@concord.org" }
    let(:auth_provider) { "portal.concord.org"   }
    let(:auth_uid)      { "23"                   }
    let(:auth_token)    { "xyzzy"                }
    let(:auth_roles)    { []                     }

    let(:auth) do
      auth_obj = double(:provider => auth_provider, :uid => auth_uid)
      allow(auth_obj).to receive_message_chain(:info, :email).and_return(auth_email)
      allow(auth_obj).to receive_message_chain(:extra, :roles).and_return(auth_roles)
      allow(auth_obj).to receive_message_chain(:credentials, :token).and_return(auth_token)
      auth_obj
    end

    describe "with matching provider and user" do
      it "should return the matching user" do

        expected = FactoryGirl.create(:user)
        authentication = FactoryGirl.create(:authentication,
          {:user => expected, :provider => auth_provider, :uid => auth_uid})

        expect(User.find_for_concord_portal_oauth(auth)).to eq(expected)
      end
    end

    describe "with matching email address and no provider" do
      it "should return the found user" do
        expected = FactoryGirl.create(:user,
          { :email => auth_email } )
        expect(User.find_for_concord_portal_oauth(auth)).to eq(expected)
      end
      it "should update the provider and user to match found" do
        expected = FactoryGirl.create(:user,
          { :email => auth_email } )
        found = User.find_for_concord_portal_oauth(auth)
        expect(found.email).to    eq(expected.email)
        authentication = found.authentications.first
        expect(authentication.provider).to eq(auth.provider)
        expect(authentication.uid).to      eq(auth.uid)
      end
    end

    describe "with matching email address and different provider" do
      it "should create a new authentication with the provider and uid" do

        expected = FactoryGirl.create(:user,
          { :email => auth_email }  )
        authentication = FactoryGirl.create(:authentication,
          {:user => expected, :provider => 'some other provider', :uid => auth_uid})
        found = User.find_for_concord_portal_oauth(auth)
        expect(found.email).to                eq(expected.email)
        expect(found.authentications.size).to eq(2)

        authentication = found.authentications.find_by_provider auth.provider
        expect(authentication).not_to eq(nil)
        expect(authentication.uid).to eq(auth.uid)
      end
    end

    describe "with matching email address and wrong uid" do
      it "should throw an excpetion" do
        expected = FactoryGirl.create(:user,
          { :email => auth_email}  )
        authentication = FactoryGirl.create(:authentication,
          {:user => expected, :provider => auth_provider, :uid => "222"})
        expect { User.find_for_concord_portal_oauth(auth) }.to raise_error
      end
    end

    describe '#auth_providers' do
      let(:user) { FactoryGirl.create(:user) }
      let(:run)  { FactoryGirl.create(:run, :remote_endpoint => 'http://localhost:9000') }
      let(:auth) { FactoryGirl.create(:authentication, :provider => 'concord_portal') }

      it 'should return an array of symbols' do
        expect(user.auth_providers).to eq([])
      end

      it 'should get providers from previous authentications' do
        user.authentications << auth
        expect(user.auth_providers).to include('CONCORD_PORTAL')
      end

      it 'should get providers from previous runs' do
        user.runs << run
        expect(user.auth_providers).to include('LOCAL')
      end
    end
  end

end
