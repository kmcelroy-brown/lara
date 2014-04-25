class AddIsPredictionToEmbeddableImageQuestion < ActiveRecord::Migration
  def change
    add_column :embeddable_image_questions, :is_prediction, :boolean, :default => false
  end
end
