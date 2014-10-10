require 'csv'

class SippParser
  attr_accessor :error
  def initialize(stats_file, test_run_instance)
    @test_run    = test_run_instance
    @stats_file  = File.new(stats_file.path, 'r')
    @data_buffer = ''
    @headers     = ''
    @data        = ''
    begin
      populate_data_buffer
    rescue EOFError
      sleep 1
      retry
    end
    initialize_headers
  end

  def initialize_headers
    @headers = @data_buffer.slice! /(.+\n)/
  end

  def populate_data_buffer
    until @data_buffer.index "\n"
      @data_buffer << @stats_file.read_nonblock(128)
    end
  rescue IO::WaitReadable
    IO.select [@stats_file]
    retry
  end

  def load_data
    data_point = ''
    while data_point = @data_buffer.slice!(/(.+\n)/)
      @data << data_point
    end
  end

  def stop
    until @stats_file.eof?
      @data_buffer << @stats_file.read_nonblock(128)
    end
    parse_data "#{@headers}#{@data_buffer}"
    @running = false
  end

  def parse_data(data)
    CSV.parse(data, headers: true, col_sep: ";").each do |row|
      next unless row
      data = {
        time: DateTime.parse(row['CurrentTime']),
        test_run: @test_run,
        total_calls: row['TotalCallCreated'],
        successful_calls: row['SuccessfulCall(P)'],
        failed_calls: row['FailedCall(P)'],
        concurrent_calls: row['CurrentCall'],
        avg_call_duration: row['CallLength(P)'],
        response_time: row['ResponseTime1(P)'],
        cps: row['CallRate(P)']
      }
      SippData.create data
    end
  end

  def run
    @running = true
    until @test_run.state =~ /complete/ || !@running
      begin
        populate_data_buffer
        load_data
        next unless @data && !@data.empty?
        parse_data "#{@headers}#{@data}"
        @data = ''
      rescue EOFError
        sleep 1
      rescue => e
        @error = e
        @running = false
      end
    end
  end
end
