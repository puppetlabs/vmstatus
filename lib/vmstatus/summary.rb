class Vmstatus::Summary
  def initialize(opts)
    @opts = opts
  end

  def output(results)
    puts ""
    puts "Number of VMs associated with running Jenkins jobs"
    puts format_line(results.queued, 'queued', :blue)
    puts format_line(results.building, 'building', :blue)
    puts ""

    puts "Number of VMs associated with completed Jenkins jobs"
    puts format_line(results.passed, 'passed', :red)
    puts format_line(results.failed, 'failed', :red)
    puts format_line(results.aborted, 'aborted', :red)
    puts format_line(results.disabled, 'disabled', :red)
    puts format_line(results.deleted, 'deleted', :red)
    puts ""

    puts "Number of VMs not associated with vSphere"
    puts format_line(results.zombie, 'zombie', :red)
    puts ""

    puts "Number of VMs not associated with any vmpooler"
    puts format_line(results.orphaned, 'orphaned', :red)
    puts ""

    puts "Number of VMs not associated with any Jenkins job"
    puts format_line(results.adhoc, 'adhoc', :yellow)
    puts format_line(results.ready, 'ready', :yellow)
    puts ""

    useful_vms = results.useful_count
    total_vms  = results.total_count
    eff = total_vms > 0 ? useful_vms / total_vms.to_f * 100 : 0

    puts "Efficiency %.1f%%, #{useful_vms} out of #{total_vms} VMs are doing useful work" % eff

    if @opts[:publish]
      begin
        host, port = @opts[:publish].split(':')
        statsd = Statsd.new(host, port)
        statsd.namespace = "vmstatus"

#        statsd.batch do |batch|
          results.state.each_pair do |name, vms|
            vmpooler2vms = vms.group_by {|vm| vm.vmpooler }

            vmpooler2vms.each_pair do |vmpooler, vs|
              statsd.gauge("#{vmpooler}.#{name}", vs.count)
            end

            statsd.gauge("all.#{name}", vms.count)
          end
      rescue ArgumentError => e
        raise ArgumentError.new("Invalid publish host:port #{@opts[:publish]}: #{e.message}")
      end
    end
  end

  private

  def format_line(vms, label, color = nil)
    line = "#{vms.count}".rjust(7, ' ') + " #{label}"
    color ? line.colorize(color) : line
  end
end
