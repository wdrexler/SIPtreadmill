require 'sippy_cup/runner'
require 'json'
require 'tempfile'

class Runner
  attr_accessor :sipp_file, :rtcp_data
  def initialize(name, scenario, opts = {})
    @name = name
    @scenario = scenario
    @stats_file = Tempfile.new('stats')
    @opts = { stats_file: @stats_file.path, media_port: Kernel.rand(16384..32767) }
    @opts.merge! opts
    @stopped = false

    @stats_collector = StatsCollector.new host: @opts[:destination], vm_buffer: @opts.delete(:vmstat_buffer), interval: 1, name: @name, user: @opts[:username], password: @opts[:password] if @opts[:password]
    @rtcp_listener   = RTCPTools::Listener.new(@opts[:media_port] + 1)

    @sipp_file = nil
    @rtcp_data = nil
    @result = nil
    @target_cps = @opts[:calls_per_second]
  rescue
    clean_up_handlers
    raise
  end

  def run
    if @stats_collector
      Thread.new { @stats_collector.run }
    end
    run_rtcp_listener

    begin
      @result = nil
      @sippy_runner = SippyCup::Runner.new @scenario.to_sippycup_scenario(@opts), full_sipp_output: false, async: true
      @sippy_runner.run
      Thread.new do
        begin
          @result = @sippy_runner.wait
        rescue => e
          @error = e
        end
      end
      until @result
        @sippy_runner.set_cps(@target_cps)
        sleep 1
      end
      raise @error if @error
    ensure
      @rtcp_listener.stop
      @stats_collector.stop if @stats_collector
    end

    unless @stopped
      rtcp_data = @rtcp_listener.organize_data
      @stats_file.rewind
      stats_data = @stats_file.read
    end
    { stats_data: stats_data, rtcp_data: rtcp_data }
  ensure
    clean_up_handlers
  end

  def set_cps(target_cps)
    @target_cps = target_cps
  end

  def stop
    @stopped = true
    @sippy_runner.stop
  end

  def run_rtcp_listener
    Thread.new do
      begin
        @rtcp_listener.run
      rescue => e
        Airbrake.notify e
      end
    end
  end

  def clean_up_handlers
    if @stats_file
      @stats_file.close
      @stats_file.unlink
    end
  end
end
