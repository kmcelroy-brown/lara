require 'spec_helper'

describe CreateCollaboration do
  let(:user) { FactoryGirl.create(:user) }
  let(:collaborators_data_url) { "http://portal.org/collaborations/123" }
  let(:collaboration_params) do
    [
      {
        name: "Foo Bar",
        email: user.email,
        learner_id: 101,
        endpoint_url: "http://portal.concord.org/dataservice/101"
      },
      {
        name: "Bar Foo",
        email: "barfoo@bar.foo",
        learner_id: 202,
        endpoint_url: "http://portal.concord.org/dataservice/202"
      }
    ]
  end
  let(:stubbed_content_type) { 'application/json' }
  let(:stubbed_token)        { 'foo'              }
  let(:headers) do
    {
      "Authorization" => stubbed_token,
      "Content-Type"  => stubbed_content_type
    }
  end
  before(:each) do
    allow(Concord::AuthPortal).to receive(:auth_token_for_url).and_return(stubbed_token)
    stub_request(:get, collaborators_data_url).with(:headers => headers).to_return(
      :status => 200,
      :body => collaboration_params.to_json, :headers => {}
    )
  end

  describe "service call" do
    # Obviously it should work only after create collaboration service is called.
    let(:new_user) { User.find_by_email(collaboration_params[1][:email]) }
    let(:material) { FactoryGirl.create(:activity) }
    let(:create_collaboration) { CreateCollaboration.new(collaborators_data_url, user, material) }

    it "should create new collaboration run" do
      create_collaboration.call
      expect(CollaborationRun.count).to eq(1)
    end

    it "should use the protocol to find the auth_token" do
      expect(Concord::AuthPortal).to receive(:auth_token_for_url).with("http://portal.org")
      create_collaboration.call
    end

    describe "when a https url is used" do
      let(:collaborators_data_url) { "https://portal.org/collaborations/123" }

      it "should pass the https protocol through to find the auth_token" do
        expect(Concord::AuthPortal).to receive(:auth_token_for_url).with("https://portal.org")
        create_collaboration.call
      end
    end

    describe "when an activity is provided as a material" do
      it "should create new run for each user" do
        create_collaboration.call
        cr = CollaborationRun.first
        expect(cr.runs.count).to eq(2)
      end
    end

    describe "when a sequence is provided as a material" do
      let(:material) {
        s = FactoryGirl.create(:sequence)
        s.activities << FactoryGirl.create(:activity)
        s.activities << FactoryGirl.create(:activity)
        s.activities << FactoryGirl.create(:activity)
        s
      }
      it "should create new runs for each user and each activity" do
        create_collaboration.call
        cr = CollaborationRun.first
        # 2 users x 3 activities
        expect(cr.runs.count).to eq(6)
      end
    end

    it "should create new users if they didn't exist before" do
      create_collaboration.call
      expect(User.exists?(email: collaboration_params[1][:email])).to eq(true)
    end
  end
end
