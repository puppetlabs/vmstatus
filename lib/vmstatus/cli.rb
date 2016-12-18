require 'redis'
require 'ruby-progressbar'
require 'slop'
require 'colorize'

require 'vmstatus/processor'
require 'vmstatus/version'

class Vmstatus::CLI
  def initialize(argv)
    @argv = argv
    @progress = ProgressBar.create(:format => '%a %B %p%% %t', :autostart => false, :autofinish => false)
  end

  def execute
    opts = Slop.parse(@argv) do |o|
      o.string '--host', 'vmpooler redis hostname', default: 'localhost'
      o.bool '-v', '--verbose', 'verbose mode'
      o.bool '-l', '--long', 'show long form of the job url'
      o.on '--version', 'print the version' do
        puts Vmstatus::VERSION
        exit
      end
      o.on '-h', '--help' do
        puts o
        exit
      end
    end

    puts "Querying #{opts[:host]}"

    results = process(opts)

    puts ""
    puts ""

    results.state.each_pair do |name, vms|
      puts "#{name.upcase}".ljust(16, ' ') + " (#{vms.count})".rjust(69, '-')
      if opts.verbose?
        vms.sort_by { |vm| vm.hostname }.each do |vm|
          color = if vm.ttl <= 0
                    :red
                  elsif vm.url.nil?
                    :yellow
                  else
                    :cyan
                  end

          checkout = vm.checkout || (' ' * 25)
          left = ("#{vm.hostname} '#{checkout}' " + ("%10.2fh" % vm.ttl) + " #{vm.user}").ljust(20, ' ')

          if opts.long?
            right = vm.url
          else
            right = vm.url.nil? ? '' : vm.url.match(/.*\/job\/([^\/]+)/)[1]
          end

          puts "#{left} #{right}".colorize(color)
        end
      end
      puts ""
    end
  end

  def process(opts)
    with_redis(opts) do |redis|
      processor = Vmstatus::Processor.new(self)
      processor.process(redis)
    end
  end

  def on_total(total)
    @progress.total = total
  end

  def on_start
    @progress.start
  end

  def on_progress(current_progress)
    @progress.increment
  end

  def on_finish
    @progress.finish
  end

  private

  def with_redis(opts, &block)
    redis = Redis.new(:host => opts[:host])
    begin
      yield redis
    ensure
      redis.close
    end
  end
end
