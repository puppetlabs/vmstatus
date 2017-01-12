require 'vmstatus/processor'
require 'vmstatus/summary'

class Vmstatus::List < Vmstatus::Summary
  def print(results)
    results.state.each_pair do |name, vms|
      puts "#{name.upcase}".ljust(16, ' ') + " (#{vms.count})".rjust(69, '-')

      vms.sort_by do |vm|
        case @opts[:sort]
        when 'checkout'
          vm.checkout
        when 'job'
          vm.job_name
        when 'ttl'
          vm.ttl
        when 'user'
          vm.user
        else
          vm.hostname
        end
      end.each do |vm|
        color = if vm.ttl <= 0
                  :red
                elsif vm.url.nil?
                  :yellow
                else
                  :cyan
                end

        checkout = vm.checkout || (' ' * 25)
        left = ("#{vm.hostname} #{checkout} " + ("%10.2fh" % vm.ttl) + " #{vm.user}").ljust(20, ' ')

        right = @opts.long? ? vm.url : vm.job_name

        puts "#{left} #{right}".colorize(color)
      end

      puts ""
    end
  end
end
