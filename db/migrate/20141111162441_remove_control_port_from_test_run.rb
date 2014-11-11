class RemoveControlPortFromTestRun < ActiveRecord::Migration
  def up
    remove_column :test_runs, :control_port
  end

  def down
    add_column :test_runs, :control_port, :integer
  end
end
