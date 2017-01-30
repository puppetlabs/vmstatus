class Vmstatus::List
  def initialize(opts)
    @opts = opts
  end

  def output(results)
    puts ""

    puts "Hostname".ljust(16) + "Status".ljust(10) + "Running".ljust(9) + "Checkout Time".ljust(25) + "TTL".rjust(12) + " User".ljust(22) + "Jenkins Job"

    results.vms.sort_by do |vm|
      case @opts[:sort]
      when 'checkout'
        [vm.checkout, vm.hostname]
      when 'job'
        [vm.job_name, vm.hostname]
      when 'ttl'
        [vm.ttl, vm.hostname]
      when 'user'
        [vm.user, vm.hostname]
      when 'host'
        vm.hostname
      else
        [vm.job_status, vm.hostname]
      end
    end.each do |vm|
      color = case vm.job_status
              when 'building', 'queued'
                :blue
              when 'unknown', 'adhoc', 'orphaned', 'ready'
                :yellow
              else
                :red
              end

      on = vm.on? ? 'on' : 'off'
      running = vm.running? ? '*' : '!'

      checkout = vm.checkout ? vm.checkout.to_s : ' '
      ttl = vm.ttl ? ("%8.2fh" % vm.ttl) : 'never'
      user = vm.user ? vm.user : ' '
      left = vm.hostname.ljust(16) + vm.job_status.ljust(10) + on.rjust(3) + "/" + running.ljust(5) + checkout.ljust(25) + ttl.rjust(12) + " " + user.ljust(20)
      right = @opts.long? ? vm.url : vm.job_name

      puts "#{left} #{right}".colorize(color)
    end

    puts ""
  end
end
