class AddDurationToProfiles < ActiveRecord::Migration
  def change
    add_column :profiles, :duration, :integer
    add_column :profiles, :use_time, :boolean
  end
end
