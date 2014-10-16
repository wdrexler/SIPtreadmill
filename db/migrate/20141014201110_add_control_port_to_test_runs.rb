class AddControlPortToTestRuns < ActiveRecord::Migration
  def change
    add_column :test_runs, :control_port, :integer
  end
end
