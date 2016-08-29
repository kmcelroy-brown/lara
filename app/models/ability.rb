class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the passed in user here.
    #
    # See the wiki for details:
    # https://github.com/ryanb/cancan/wiki/Defining-Abilities

    user ||= User.new # guest user (not logged in)
    if user.admin?
      # Admins can do everything
      can :manage, :all
      can :inspect, Run
      can :manage, QuestionTracker
      can :report, QuestionTracker
    elsif user.author?
      # Authors can create new items and manage those they created
      can :create, Sequence
      can :create, LightweightActivity
      can :create, InteractivePage
      can :manage, Sequence, :user_id => user.id
      can :manage, LightweightActivity, :user_id => user.id
      can :manage, InteractivePage, :lightweight_activity => { :user_id => user.id }
      # and duplicate unlocked activities and sequences
      can :duplicate, LightweightActivity, :is_locked => false, :publication_status => ['public', 'hidden']
      can :duplicate, Sequence, :publication_status => ['public', 'hidden']
      # other users cannot export an activity or sequence
      cannot :export, LightweightActivity
      cannot :export, Sequence
    end
    # Everyone (author and regular user) can read public, hidden and archived sequences or activities.
    ['public', 'hidden', 'archive'].each do |allowed_status|
      can :read, Sequence, :publication_status => allowed_status
      can :read, LightweightActivity, :publication_status => allowed_status
      can :read, InteractivePage, :lightweight_activity => { :publication_status => allowed_status }
    end

    can :about, Project
    can :help, Project
    can :contact_us, Project

    can :access, Run do |run|
      if user.admin?
        true
      elsif user.new_record?
        # We're currently anonymous
        run.user_id.nil?
      else
        run.user_id == user.id
      end
    end

    can [:show, :update], InteractiveRunState do |interactive_run_state|
      # admins can do anything, unowned runs can be read/written by anyone, owned runs only by their owner
      user.admin? || interactive_run_state.run.user.nil? || (user == interactive_run_state.run.user)
    end
  end
end
