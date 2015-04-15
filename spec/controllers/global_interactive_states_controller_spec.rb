require 'spec_helper'

describe GlobalInteractiveStatesController do

  describe 'routing' do
    it '#create' do
      expect(post: 'runs/88e0aff5-db3f-4087-8fda-49ec579980ee/global_interactive_state').to route_to(controller: 'global_interactive_states', action: 'create', run_id: '88e0aff5-db3f-4087-8fda-49ec579980ee')
    end
  end

  let (:user) { FactoryGirl.create(:user) }
  before(:each) do
    sign_in user
  end

  describe '#create' do
    let (:run) { FactoryGirl.create(:run, user: user) }
    let (:new_state) { 'test 123' }

    context 'when there is no global interactive state connected with given run' do
      it 'should create a new one' do
        expect {
          post :create, run_id: run.key, raw_data: new_state
        }.to change(GlobalInteractiveState, :count).by(1)
        expect(GlobalInteractiveState.first.raw_data).to eql(new_state)
        expect(response.status).to eql(201)
      end
    end

    context 'when there is an existing global interactive state connected with given run' do
      before(:each) do
        FactoryGirl.create(:global_interactive_state, run: run)
      end
      it 'should update it' do
        expect {
          post :create, run_id: run.key, raw_data: new_state
        }.to change(GlobalInteractiveState, :count).by(0)
        expect(GlobalInteractiveState.first.raw_data).to eql(new_state)
        expect(response.status).to eql(200)
      end
    end

    context "when user is trying to modify someone else's run" do
      let (:different_user) { FactoryGirl.create(:user) }
      let (:run) { FactoryGirl.create(:run, user: different_user) }
      it 'it should fail' do
        expect {
          post :create, run_id: run.key, raw_data: new_state
        }.to change(GlobalInteractiveState, :count).by(0)
        expect(response.status).to eql(400)
      end
    end
  end
end
