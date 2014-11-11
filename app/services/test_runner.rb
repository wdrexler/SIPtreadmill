require 'tempfile'

class TestRunner
  BIND_IP = ENV['TEST_RUN_BIND_IP']

  attr_accessor :stopped

  def initialize(test_run, job_id, ssh_password = nil)
    @test_run = test_run
    @jid = job_id
    @stopped = false
    @receiver_runner = nil
    @receiver_error = nil
    @sipp_parser = nil
    @password = ssh_password
    @vmstat_buffer = []
    @csv_files = []
    @results   = []
    @errors    = []
  end

  def run
    execute_registration_scenario
    start_receiver_scenario

    execute_runners

    unless @stopped
      @results.each do |result|
        parse_rtcp_data result[:rtcp_data], @test_run.test_run_scenarios.first
      end
      parse_system_stats @vmstat_buffer if has_stats_credentials?
    end

    @test_run.summary_report = @results[0][:summary_report] if @results[0]
    @test_run.errors_report_file = @results[0][:errors_report_file] if @results[0]
    @test_run.stats_file = @results[0][:stats_file] if @results[0]
    @test_run.save!
  ensure
    halt_receiver_scenario
    close_csv_files
  end

  def set_cps(target_cps)
    @runners.each do |r|
      r[0].set_cps target_cps
    end
  end

  def stop
    @stopped = true
    @runner.stop
  end

  private

  def execute_registration_scenario
    return unless @test_run.registration_scenario

    options = {
      number_of_calls: 1,
      calls_per_second: 1,
      max_concurrent: 1,
      destination: @test_run.target.address,
      source: TestRunner::BIND_IP,
      source_port: @test_run.local_ports_array[0],
      transport_mode: @test_run.profile.transport_type.to_s,
    }
    options[:scenario_variables] = write_csv_data @test_run.registration_scenario if @test_run.registration_scenario.csv_data.present?
    scenario = @test_run.registration_scenario.to_sippycup_scenario options
    cup = SippyCup::Runner.new scenario, full_sipp_output: false
    cup.run
  end

  def start_receiver_scenario
    return unless @test_run.receiver_scenario

    options = {
      source: TestRunner::BIND_IP,
      source_port: @test_run.local_ports_array[0],
      transport_mode: @test_run.profile.transport_type.to_s,
      receiver_mode: true
    }

    options[:scenario_variables] = write_csv_data @test_run.receiver_scenario if @test_run.receiver_scenario.csv_data.present?

    scenario = @test_run.receiver_scenario.to_sippycup_scenario options
    @receiver_runner = SippyCup::Runner.new scenario, full_sipp_output: false, async: true
    @receiver_runner.run
  rescue SippyCup::SippGenericError
    # Prevent SIPp from giving us a false negative due to SIGUSR1
  end

  def halt_receiver_scenario
    return unless @receiver_runner
    @receiver_runner.stop
    @receiver_runner.wait
  end

  def execute_runners
    @runners = []
    @test_run.test_run_scenarios.all[0..-2].each_with_index do |test_run_scenario, i|
      @runners << execute_runner(test_run_scenario, async: true, scenario_index: i)
    end

    last = @test_run.test_run_scenarios.last
    @runners << execute_runner(last, scenario_index: (@test_run.test_run_scenarios.count - 1))

    until @runners.select { |r| r[1].status }.empty?
      sleep 1
    end
    sleep 1
    puts "ERRORS #{@errors.inspect}"
  end

  def execute_runner(test_run_scenario, opts = {})
    result      = nil
    sipp_parser = nil
    runner_opts = {
      source: TestRunner::BIND_IP,
      destination: @test_run.target.address,
      source_port: @test_run.local_ports_array[opts[:scenario_index] + 1],
      number_of_calls: @test_run.profile.max_calls,
      calls_per_second: @test_run.profile.calls_per_second,
      max_concurrent: @test_run.profile.max_concurrent,
      to_user: @test_run.to_user,
      transport_mode: @test_run.profile.transport_type.to_s,
      vmstat_buffer: @vmstat_buffer,
      advertise_address: @test_run.advertise_address,
      from_user: @test_run.from_user,
      options: Psych.safe_load(@test_run.sipp_options),
      use_time: @test_run.profile.use_time,
      time_limit: @test_run.profile.duration,
      control_port: test_run_scenario.control_port
    }

    runner_opts[:scenario_variables] = write_csv_data test_run_scenario.scenario if test_run_scenario.scenario.csv_data.present?

    if @test_run.profile.calls_per_second_max
      opts[:calls_per_second_max] = @test_run.profile.calls_per_second_max
      opts[:calls_per_second_incr] = @test_run.profile.calls_per_second_incr
      opts[:calls_per_second_interval] = @test_run.profile.calls_per_second_interval
    end

    unless opts[:async] || !has_stats_credentials?
      runner_opts[:password] = @password
      runner_opts[:username] = @test_run.target.ssh_username
    end

    runner = Runner.new runner_name, test_run_scenario.scenario, runner_opts
    Thread.new do
      sipp_parser = SippParser.new runner.stats_file, test_run_scenario
      sipp_parser.run
      @errors << sipp_parser.error if sipp_parser.error
    end
    runner_thread = Thread.new do
      begin
        result = runner.run
        @results << result
      rescue => e
        @errors << e
      ensure
        Thread.current.exit
      end
    end
    [runner, runner_thread]
  end

  def path(suffix = '')
    File.join "/tmp", @jid, suffix
  end

  def write_csv_data(scenario)
    t = Tempfile.new 'csv'
    t.write scenario.csv_data
    t.rewind

    @csv_files << t
    t.path
  end

  def close_csv_files
    @csv_files.each do |f|
      f.close
      f.unlink
    end
  end

  def runner_name
    @test_run.name.downcase.gsub(/\W/, '')
  end

  def parse_rtcp_data(data, test_run_scenario)
    return unless data
    RtcpParser.new(data, test_run_scenario).run
  end

  def parse_system_stats(buffer)
    return unless buffer
    VMStatParser.new(buffer, @test_run).parse
  end

  def has_stats_credentials?
    @test_run.target.ssh_username.present? && !@password.nil?
  end
end
