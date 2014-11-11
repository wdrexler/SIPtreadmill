class TestRun < ActiveRecord::Base
  attr_accessible :description, :name, :jid, :enqueued_at, :started_at, :completed_at
  attr_accessible :profile, :profile_id
  attr_accessible :target, :target_id
  attr_accessible :test_run_scenarios_attributes
  attr_accessible :receiver_scenario, :receiver_scenario_id
  attr_accessible :registration_scenario, :registration_scenario_id
  attr_accessible :local_ports
  belongs_to :profile
  has_many :test_run_scenarios
  has_many :scenarios, through: :test_run_scenarios
  belongs_to :receiver_scenario, class_name: "Scenario"
  belongs_to :target
  belongs_to :user
  has_many :sipp_data, class_name: "SippData", through: :test_run_scenarios
  has_many :rtcp_data, class_name: "RtcpData", through: :test_run_scenarios
  has_many :system_load_data, class_name: "SystemLoadDatum"
  delegate :first_name, :last_name, :to => :user, :prefix => true
  delegate :name, :to => :scenario, :prefix => true
  delegate :name, :to => :profile, :prefix => true
  delegate :name, :to => :target, :prefix => true
  delegate :registration_scenario, :to => :receiver_scenario, allow_nil: true
  validates_presence_of :name, :profile, :target, :user
  mount_uploader :errors_report_file, ErrorsReportFileUploader
  mount_uploader :stats_file, StatsFileUploader
  delegate :url, to: :errors_report_file, prefix: true
  delegate :url, to: :stats_file, prefix: true
  accepts_nested_attributes_for :test_run_scenarios

  validate :validate_scenarios
  after_save  :save_test_run_scenarios

  STOP_JOBS_NAMESPACE = 'stopjobs'

  def validate_scenarios
    if receiver_scenario.present? && receiver_scenario.receiver == false
      errors.add(:scenario, "Please select a receiver scenario.")
    end
  end

  def save_test_run_scenarios
    self.test_run_scenarios.all.each do |trs|
      trs.save
    end
  end

  def duplicate
    new_run = TestRun.new(scenario_id: self.scenario.id, profile_id: self.profile.id,
                               target_id: self.target.id, description: self.description, local_ports: self.local_ports)
    new_run.user = self.user
    new_run.receiver_scenario_id = self.receiver_scenario.id if self.receiver_scenario
    if match = self.name.match(/Retry (\d+)$/)
      retry_number = match[1].to_i + 1
      new_run.name = self.name.gsub /\d+$/, retry_number.to_s
    else
      new_run.name = "#{self.name} Retry 1"
    end
    new_run.save
    new_run
  end

  def max_jitter
    self.rtcp_data.maximum 'max_jitter'
  end

  def avg_jitter
    self.rtcp_data.average 'avg_jitter'
  end

  def max_packet_loss
    self.rtcp_data.maximum 'max_packet_loss'
  end

  def avg_packet_loss
    self.rtcp_data.average 'avg_packet_loss'
  end

  def total_calls
    self.sipp_data.last.total_calls if sipp_data.last
  end

  def successful_calls
    self.sipp_data.last.successful_calls if sipp_data.last
  end

  def failed_calls
    self.sipp_data.last.failed_calls if sipp_data.last
  end

  def avg_call_duration
    self.sipp_data.last.avg_call_duration if sipp_data.last
  end

  def avg_cps
    self.sipp_data.average 'cps'
  end

  def local_ports_array
    JSON.parse self.local_ports
  rescue => e
    []
  end

  def local_ports_array=(new_local_ports)
    raise ArgumentError, "Must set local ports to an array value" unless new_local_ports.kind_of?(Array)
    raise ArgumentError, "Local ports must be unique" unless new_local_ports.uniq == new_local_ports
    self.local_ports = new_local_ports.map do |e|
      if e.to_i > 1024
        e.to_i
      else
        Kernel.rand(10000...65535)
      end
    end.to_json
  end

  def test_run_scenarios_attributes=(attrs)
    attrs.each do |i, v|
      puts "BUILDING NEW TRS FOR #{v.inspect}"
      if self.test_run_scenarios.all[i.to_i]
        trs = self.test_run_scenarios.all[i.to_i]
      else
        trs = self.test_run_scenarios.build
      end
      trs.scenario = Scenario.find v[:scenario_id].to_i
      trs.test_run = self
      puts "ERRORS: #{trs.errors.inspect}"
    end
    (self.test_run_scenarios.all[(attrs.size)..-1] || []).map &:destroy
  end

  def total_calls_colors
    count  = self.test_run_scenarios.count
    r      = Array.new(count, '#ff2a2a')
    g      = Array.new(count, '#55ff55')
    y      = Array.new(count, '#ffcc00')
    [g, r, y].flatten
  end

  def total_calls_json
    data = [[], [], []]
    self.test_run_scenarios.all.each_with_index do |trs, i|
      trs_data = [{key: "Successful (#{i})", values: []}, {key: "Failed (#{i})", values: []}, {key: "Started (#{i})", values: []}]
      trs.sipp_data.all.each do |d|
        time = d.time.to_i * 1000 #Convert to JS epoch
        trs_data[0][:values] << [time, d.successful_calls]
        trs_data[1][:values] << [time, d.failed_calls]
        trs_data[2][:values] << [time, d.cps]
      end
      puts data.inspect
      puts trs_data.inspect
      data[0] << trs_data[0]
      data[1] << trs_data[1]
      data[2] << trs_data[2]
      data.map! { |d| d.flatten!; d }
    end
    data.flatten.to_json
  end

  def jitter_json
    data = [{key: "Average Jitter", values: []}, {key: "Max Jitter", values: []}]
    self.rtcp_data.all.each do |d|
      time = d.time.to_i * 1000
      data[0][:values] << [time, d.avg_jitter]
      data[1][:values] << [time, d.max_jitter]
    end
    data.to_json
  end

  def call_rate_json
    data = [{key: "Calls Per Second", values: []}, {key: "Concurrent Calls", values: []}]
    self.sipp_data.all.each do |d|
      time = d.time.to_i * 1000
      data[0][:values] << [time, d.cps]
      data[1][:values] << [time, d.concurrent_calls]
    end
    data.to_json
  end

  def packet_loss_json
    data = [{key: "Average Packet Loss", values: []}, {key: "Max Packet Loss", values: []}]
    self.rtcp_data.all.each do |d|
      time = d.time.to_i * 1000
      data[0][:values] << [time, d.avg_packet_loss]
      data[1][:values] << [time, d.max_packet_loss]
    end
    data.to_json
  end

  def target_resources_json
    data = [{key: "CPU", values: []}, {key: "Memory", values: []}]
    self.system_load_data.all.each do |d|
      time = d.logged_at.to_i * 1000
      data[0][:values] << [time, d.cpu]
      data[1][:values] << [time, d.memory]
    end
    data.to_json
  end

  def stats_json
    { total_calls: self.total_calls, successful_calls: self.successful_calls,
      failed_calls: self.failed_calls, avg_call_duration: self.avg_call_duration,
      avg_jitter: self.avg_jitter, max_jitter: self.max_jitter,
      avg_packet_loss: self.avg_packet_loss, max_packet_loss: self.max_packet_loss }
  end

  def html_status
    case self.state
    when 'pending'
      ['', 'Pending']
    when 'queued'
      ['label-inverse', 'Queued']
    when 'running'
      ['label-info', 'Running']
    when 'complete'
      ['label-success', 'Complete']
    when 'complete_with_warnings'
      ['label-warning', 'Warnings']
    when 'complete_with_errors'
      ['label-important', 'Errors']
    end
  end

  state_machine :initial => :pending do
    after_transition on: :enqueue do |test_run, transition|
      jid = TestRunWorker.perform_async(test_run.id, transition.args.first)
      unless jid
        raise "Failed to enqueue job!"
      end
      test_run.jid = jid
      test_run.enqueued_at = Time.now
      test_run.save
    end

    after_transition on: :cancel do |test_run, transition|
      queue = Sidekiq::Queue.new
      queue.each do |job|
        job.delete if job.jid == test_run.jid
      end
    end

    after_transition on: :start do |test_run, transition|
      test_run.started_at = Time.now
      test_run.save
    end

    after_transition on: :complete do |test_run, transition|
      test_run.completed_at = Time.now
      test_run.save
    end

    after_transition on: :stop do |test_run, transition|
      if test_run.jid
        Sidekiq.redis do |r|
          r.sadd STOP_JOBS_NAMESPACE,  test_run.jid
        end
      end
    end

    event :enqueue do
      transition :pending => :queued
    end

    event :start do
      transition [:pending, :queued] => :running
    end

    event :complete do
      transition :running => :complete
    end

    event :stop do
      transition :running => :pending
    end

    event :cancel do
      transition :queued => :pending
    end

    event :complete_with_errors do
      transition all => :complete_with_errors
    end
  end
end
