
class Plugin < ActiveRecord::Base

  attr_accessible :description, :author_data, :approved_script_id, :approved_script, :shared_learner_state_key

  belongs_to :approved_script
  belongs_to :plugin_scope, polymorphic: true

  delegate :name,  to: :approved_script, allow_nil: true
  delegate :label, to: :approved_script, allow_nil: true
  delegate :url,   to: :approved_script, allow_nil: true
  delegate :version, to: :approved_script, allow_nil: true

  after_initialize :generate_rare_key

  def generate_rare_key
    self.shared_learner_state_key ||= SecureRandom.uuid()
  end

  def to_hash
    {
      description: description,
      author_data: author_data,
      approved_script_id: approved_script_id,
      shared_learner_state_key: shared_learner_state_key
    }
  end

  def duplicate
    return Plugin.new(self.to_hash)
  end

end
