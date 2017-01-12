require 'vmstatus/processor'

class Vmstatus::Summary
  def initialize(opts)
    @opts = opts
  end

  def run(observer)
    results =
      with_redis do |redis|
      processor = Vmstatus::Processor.new(observer)
      processor.process(redis)
    end

    puts ""

    print(results)

    if @opts[:publish]
      begin
        host, port = @opts[:publish].split(':')
        statsd = Statsd.new(host, port)
        results.state.each_pair do |name, vms|
          statsd.gauge("vmstatus.#{name}", vms.count)
        end
      rescue ArgumentError => e
        puts "Invalid publish host:port #{@opts[:publish]}: #{e.message}"
        exit 1
      end
    end
  end

  def print(results)
    puts "Number of VMs associated with running Jenkins jobs"
    puts format_line(results.state[:queued], 'queued')
    puts format_line(results.state[:ready], 'ready')
    puts format_line(results.state[:ok], 'building')
    puts ""

    puts "Number of VMs associated with completed Jenkins jobs"
    puts format_line(results.state[:passed], 'passed', :red)
    puts format_line(results.state[:failed], 'failed', :red)
    puts format_line(results.state[:aborted], 'aborted', :red)
    puts format_line(results.state[:disabled], 'disabled', :red)
    puts format_line(results.state[:deleted], 'deleted', :red)
    puts ""

    puts "Number of VMs not associated with any Jenkins job"
    puts format_line(results.state[:unknown_running], 'unknown', :yellow)
    puts format_line(results.state[:unknown_dead], 'missing', :yellow)
    puts ""

    useful_vms = results.state[:queued].count + results.state[:ok].count
    total_vms = results.state.values.inject(0) { |sum, vms| sum + vms.count }
    eff = total_vms > 0 ? useful_vms / total_vms.to_f * 100 : 0

    puts "Efficiency %.1f%%, #{useful_vms} out of #{total_vms} VMs are doing useful work" % eff
  end

  private

  def format_line(vms, label, color = nil)
    line = "#{vms.count}".rjust(7, ' ') + " #{label}"
    color ? line.colorize(color) : line
  end

  def with_redis(&block)
    redis = Redis.new(:host => @opts[:host])
    begin
      yield redis
    ensure
      redis.close
    end
  end

end
