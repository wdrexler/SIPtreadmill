class TestRunScenario < ActiveRecord::Base
	belongs_to :test_run
	belongs_to :scenario
	has_many :sipp_data, class_name: "SippData"
	has_many :rtcp_data, class_name: "RtcpData"
	attr_accessible :control_port
	before_save :generate_control_port

	def generate_control_port
		self.control_port = Kernel.rand 10000...65535
	end
end
