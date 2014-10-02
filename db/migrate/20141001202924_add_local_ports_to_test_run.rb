class AddLocalPortsToTestRun < ActiveRecord::Migration
  def change
    add_column :test_runs, :local_ports, :text
  end
end
