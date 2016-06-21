module Embeddable
  class OpenResponse < ActiveRecord::Base
    include Embeddable


    attr_accessible :name, :prompt, :is_prediction, :give_prediction_feedback, :prediction_feedback, :default_text, :is_hidden

    # PageItem instances are join models, so if the embeddable is gone the join should go too.
    has_many :page_items, :as => :embeddable, :dependent => :destroy
    has_many :interactive_pages, :through => :page_items
    has_many :answers,
      :class_name  => 'Embeddable::OpenResponseAnswer',
      :foreign_key => 'open_response_id'

    has_one :tracked_question, :as => :question, :dependent => :delete
    has_one :question_tracker, :through => :tracked_question
    has_one :master_for_tracker, :class_name => 'QuestionTracker', :as => :master_question

    default_value_for :prompt, "why does ..."

    def to_hash
      {
        name: name,
        prompt: prompt,
        is_prediction: is_prediction,
        give_prediction_feedback: give_prediction_feedback,
        prediction_feedback: prediction_feedback,
        default_text: default_text,
        is_hidden: is_hidden
      }
    end

    def duplicate
      return Embeddable::OpenResponse.new(self.to_hash)
    end

    def self.name_as_param
      :embeddable_open_response
    end

    def self.display_partial
      :open_response
    end

    def self.human_description
      "Multiple choice question"
    end

    def export
      return self.as_json(only:[:name,
                                :prompt,
                                :is_prediction,
                                :give_prediction_feedback,
                                :prediction_feedback,
                                :default_text,
                                :is_hidden])
    end

    def self.import (import_hash)
      return self.new(import_hash)
    end

    # SettingsProviderFunctionality extends the functionality of duplicate, export and import using alias_method_chain.
    # So these methods needs to be visible to the SettingsProviderFunctionality.
    include CRater::SettingsProviderFunctionality
  end
end
