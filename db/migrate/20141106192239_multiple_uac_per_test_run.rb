class MultipleUacPerTestRun < ActiveRecord::Migration
  def up
    create_table :test_run_scenarios do |t|
      t.integer :test_run_id
      t.integer :scenario_id
    end
    remove_column :test_runs, :scenario_id
    remove_column :sipp_data, :test_run_id
    add_column    :sipp_data, :test_run_scenario_id, :integer
    remove_column :rtcp_data, :test_run_id
    add_column    :rtcp_data, :test_run_scenario_id, :integer
  end

  def down
  end
end
