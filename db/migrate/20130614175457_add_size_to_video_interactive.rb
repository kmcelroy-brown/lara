class AddSizeToVideoInteractive < ActiveRecord::Migration
  def change
    add_column :video_interactives, :width, :integer, :default => 556, :null => false
    add_column :video_interactives, :height, :integer, :default => 240, :null => false
  end
end
