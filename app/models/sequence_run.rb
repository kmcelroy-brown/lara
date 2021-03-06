class SequenceRun < ActiveRecord::Base
  attr_accessible :remote_endpoint, :remote_id, :user_id, :sequence_id

  has_many :runs
  belongs_to :sequence
  belongs_to :user

  def self.lookup_or_create(sequence, user, portal)

    conditions = {
      remote_endpoint: portal.remote_endpoint,
      remote_id:       portal.remote_id,
      user_id:         user.id,
      sequence_id:     sequence.id
      #TODO: add domain
    }
    found = self.find(:first, :conditions => conditions)
    found ||= self.create(conditions)
    found.make_or_update_runs
    found
  end

  def run_for_activity(activity)
    runs.find {|run| run.activity_id == activity.id}
  end

  def most_recent_run
    runs.order('updated_at desc').first
  end

  def most_recent_activity
    most_recent_run.activity
  end

  def has_been_run
    a_position =  runs.detect { |r| r.has_been_run }
    return a_position.nil? ? false : true
  end

  def disable_collaboration
    # In theory we could keep reference to collaboration run in sequence.
    # However this approach seems to be more bulletproof, as it will definitely clear any possible
    # collaboration (it's not likely, but it may happen that there are a few different collaborations
    # related to different runs, not just single one).
    runs.select { |r| r.collaboration_run }.each { |r| r.collaboration_run.disable }
  end

  def make_or_update_runs
    sequence.activities.each do |activity|
      unless run_for_activity(activity)
        runs.create!({
          remote_endpoint: remote_endpoint,
          remote_id:       remote_id,
          user_id:         user.id,
          activity_id:     activity.id,
          sequence_id:     sequence.id
          })
      end
    end
  end

  def completed?
    runs.count == sequence.activities.count && runs.all? { |r| r.completed? }
  end
end
