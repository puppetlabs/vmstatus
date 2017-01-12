require 'redis'
require 'ruby-progressbar'
require 'slop'
require 'colorize'
require 'statsd'

require 'vmstatus/summary'
require 'vmstatus/list'
require 'vmstatus/version'

class Vmstatus::CLI
  def initialize(argv)
    @argv = argv
    @progress = ProgressBar.create(:format => '%a %B %p%% %t', :autostart => false, :autofinish => false)
  end

  def execute
    opts = Slop.parse(@argv) do |o|
      o.separator 'Commands:'
      o.separator '     list          List status of all running VMs'
      o.separator '     summary       Summary of VM status'
      o.separator ''
      o.separator 'Options:'
      o.string '--host', 'vmpooler redis hostname', default: 'localhost'
      o.bool '-v', '--verbose', 'verbose mode'
      o.bool '-l', '--long', 'show long form of the job url'
      o.string '-s', '--sort', "sort by 'host', 'checkout', 'ttl', 'user', 'job'", default: 'host'
      o.string '-p', '--publish', 'publish stats <host:port>'
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

    command = opts.arguments.first
    case command
    when 'list'
      Vmstatus::List.new(opts).run(self)
    when 'summary'
      Vmstatus::Summary.new(opts).run(self)
    else
      puts "Unknown command '#{command}'\n" if command
      puts opts.options
      exit 1
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
end
