require 'sippy_cup/runner'
require 'json'
require 'tempfile'

class Runner
  attr_accessor :sipp_file, :rtcp_data
  def initialize(name, scenario, profile, target)
    @name = name
    @stats_file = Tempfile.new('stats')
    @opts = { stats_file: @stats_file.path, full_sipp_output: false, media_port: Kernel.rand(16384..32767) }
    @opts.merge! scenario
    @opts.merge! profile
    @opts.merge! target
    @stopped = false

    @stats_collector = StatsCollector.new host: @opts[:destination], vm_buffer: @opts.delete(:vmstat_buffer), interval: 1, name: @name, user: @opts[:username], password: @opts[:password] if @opts[:password]
    @rtcp_listener   = RTCPTools::Listener.new(@opts[:media_port] + 1)

    @sipp_file = nil
    @rtcp_data = nil
    @ssh_error = nil
  rescue
    clean_up_handlers
    raise
  end

  def run
    if @stats_collector
      run_and_catch_errors mode: :error do
        @stats_collector.run
      end  
    end

    run_and_catch_errors mode: :notify do
      @rtcp_listener.run
    end

    begin
      @sippy_runner = SippyCup::Runner.new(@opts)
      @sippy_runner.run
      check_ssh_errors
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

  def stop
    @stopped = true
    @sippy_runner.stop
  end
        
  def run_and_catch_errors(opts = {})
    Thread.new do
      begin
        yield
      rescue => e
        case opts[:mode]
        when :notify
          Airbrake.notify e
        when :error
          @ssh_error = e
        end
      end
    end
  end
 
  def check_ssh_errors
    raise @ssh_error if @ssh_error
  end
  
  def clean_up_handlers
    if @stats_file
      @stats_file.close
      @stats_file.unlink
    end
  end
end
