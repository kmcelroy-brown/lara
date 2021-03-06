class CRater::ScoreMapping < ActiveRecord::Base
  serialize :mapping
  attr_accessible :mapping, :description
  belongs_to :user
  belongs_to :changed_by, :class_name => 'User'
  
  scope :public, self.all
  scope :newest, order("updated_at DESC")

  scope :rationale,   -> { where('description LIKE ?', '%[rationale]%').order('created_at ASC') }
  scope :explanation, -> { where('description LIKE ?', '%[explanation]%').order('created_at ASC') }

  MAP_KEY = 'score'

  def map_key(score)
    "#{MAP_KEY}#{score.to_s}"
  end

  def feedback_for(score)
    if mapping
      mapping[map_key(score)]
    else
      nil
    end
  end

  def get_feedback_text(score)
    return I18n.t('ARG_BLOCK.TEST_MODEL') if score == -1
    text = feedback_for(score)
    return I18n.t('ARG_BLOCK.NO_FEEDBACK_TEXT', score: score) unless text
    text
  end

  # The maximum score is inferred from mapping
  def max_score
    mapping.select{ |x,v| v.present? }.keys.map { |k| k.gsub(/#{MAP_KEY}/,'').to_i }.max || -1
  end

  def method_missing(method_sym, *arguments, &block)
    if method_sym.to_s =~ /^#{MAP_KEY}(\d+)$/
      feedback_for($1)
    else
      super
    end
  end

  def self.respond_to?(method_sym, include_private = false)
    if method_sym.to_s =~ /^#{MAP_KEY}(\d+)$/
      true
    else
      super
    end
  end
  
  def self.my(user)
    where(:user_id => user.id)
  end
  
  def self.visible(user)
    self.scoped
  end
  
end
