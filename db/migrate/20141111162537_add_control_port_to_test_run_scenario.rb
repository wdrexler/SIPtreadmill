class AddControlPortToTestRunScenario < ActiveRecord::Migration
  def change
    add_column :test_run_scenarios, :control_port, :integer
  end
end
