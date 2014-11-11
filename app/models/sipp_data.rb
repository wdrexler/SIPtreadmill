class SippData < ActiveRecord::Base
  attr_accessible :avg_call_duration, :concurrent_calls, :cps, :failed_calls, :response_time, :successful_calls, :test_run_scenario, :time, :total_calls
  belongs_to :test_run_scenario
end
