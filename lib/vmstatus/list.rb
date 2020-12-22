class Vmstatus::List
  def initialize(opts)
    @opts = opts
  end

  def output(results)
    puts ""

    puts "Hostname".ljust(25) + "IP(vm)".ljust(16) + "IP(dns)".ljust(16) + "Cluster Host".ljust(45) + "Type".ljust(23) + "Pooler".ljust(8) + "Status".ljust(10) + "Running".ljust(9) +
             "Creation Time Vcenter".ljust(25) + "Checkout Time".ljust(25) + "TTL".rjust(12) + " User".ljust(22) + "Jenkins Job"

    countcluster = Hash.new
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
      when 'pooler'
        [vm.vmpooler || 'none', vm.status, vm.hostname]
      when 'type'
        [vm.type || 'unknown', vm.status, vm.hostname]
      else
        [vm.status, vm.hostname]
      end
    end.each do |vm|
      color = case vm.status
              when 'building', 'queued'
                :blue
              when 'adhoc', 'ready'
                :yellow
              else
                :red
              end

      hostname = vm.hostname.length > 24 ? (vm.hostname[0..21] + "...") : vm.hostname
      vmip = vm.vmip ? vm.vmip : "N/A"
      dnsip = vm.dnsip ? vm.dnsip: "N/A"
      if dnsip != vmip
        dnsip = "*#{dnsip}"
      end
      clusterhost = vm.clusterhost ? vm.clusterhost : "N/A"
      type = vm.type ? (vm.type.length > 22 ? (vm.type[0..18] + "...") : vm.type) : 'unknown'
      # maps the vmpooler host to CI type, redis used to run on the same host as the vmpooler application.
      pooler = case vm.vmpooler
               when 'vmpooler'
                 'ci-old'
               when 'vmpooler-cinext'
                 'ci-next'
               when 'vmpooler-dev'
                 'ci-dev'
               when 'vmpooler-redis-prod-2.delivery.puppetlabs.net'
                 'ci-next'
               else
                 vm.vmpooler ? vm.vmpooler[0..3] + "..." : 'none'
               end
      on = vm.on? ? vm.on? : 'N/A'
      running = vm.running? ? '*' : '!'
      creation_timestamp = vm.creation_timestamp ? vm.creation_timestamp : ' '
      checkout = vm.checkout ? vm.checkout.to_s : ' '
      ttl = vm.ttl ? ("%8.2fh" % vm.ttl) : 'never'
      user = vm.user ? vm.user : ' '

      left = hostname.ljust(25) + vmip.ljust(16) + dnsip.ljust(16) + clusterhost.ljust(45) + type.ljust(23) + pooler.ljust(8) + vm.status.ljust(10) + on.rjust(3) + "/" + running.ljust(5) +
          creation_timestamp.ljust(25) + checkout.ljust(25) + ttl.rjust(12) + " " + user.ljust(20)
      right = @opts.long? ? vm.url : vm.job_name

      puts "#{left} #{right}".colorize(color)

      # count for each cluster host
      if vm.on? == "poweredOn" # only count when VM is on
        if !countcluster[clusterhost]
          countcluster[clusterhost] = 1
        else
          countcluster[clusterhost] = countcluster[clusterhost] + 1
        end
      end
    end

    puts ""
    puts "Cluster host count of VM that are powered on"
    countcluster.sort_by {|host, count| host}.each do |host, count|
      puts "#{host} #{count}"
    end
  end
end
