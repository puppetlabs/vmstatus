require 'redis'
require 'ruby-progressbar'
require 'slop'
require 'colorize'
require 'statsd'

require 'vmstatus/list'
require 'vmstatus/processor'
require 'vmstatus/summary'
require 'vmstatus/version'
require 'vmstatus/vsphere'

class Vmstatus::CLI
  def initialize(argv)
    @argv = argv
    @progress = ProgressBar.create(:format => '%a %B %p%% %t', :autostart => false, :autofinish => false)
  end

  def execute
    opts = Slop.parse(@argv) do |o|
      o.separator 'Commands:'
      o.separator '     list          List status of all VMs'
      o.separator '     summary       Summary of VM status'
      o.separator ''
      o.separator 'Options:'
      o.string '--host', 'vsphere hostname', default: 'localhost'
      o.string '--user', 'vsphere user'
      o.string '--password', 'vsphere password', default: ENV['LDAP_PASSWORD']
      o.string '--datacenter', 'vsphere datacenter', default: 'opdx2'
      o.string '--cluster', 'vsphere cluster', default: 'acceptance1'
      o.array '--vmpooler', 'comma-separated list of vmpooler hostnames', delimiter: ',', default: ['vmpooler','vmpooler-cinext','vmpooler-dev']
      o.bool '-v', '--verbose', 'verbose mode'
      o.bool '-l', '--long', 'show long form of the job url'
      o.string '-s', '--sort', "sort by 'host', 'checkout', 'ttl', 'user', 'job', 'status'", default: 'status'
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

    if opts[:user].nil?
      raise ArgumentError.new("Specify the vsphere (LDAP) username, e.g. 'user@puppet.com'")
    elsif opts[:password].nil?
      raise ArgumentError.new("Specify the vsphere (LDAP) password or set ENV['LDAP_PASSWORD']")
    end

    formatter = nil
    command = opts.arguments.first
    case command
    when 'list'
      formatter = Vmstatus::List.new(opts)
    when 'summary'
      formatter = Vmstatus::Summary.new(opts)
    else
      puts "Unknown command '#{command}'\n" if command
      puts opts.options
      exit 1
    end

    on_total(1000)
    on_start

    vsphere = Vmstatus::Vsphere.new(opts)
    processor = Vmstatus::Processor.new(vsphere, opts[:vmpooler], self)
    results = processor.process

    on_finish
    formatter.output(results)
  end

  def on_total(total)
    @progress.total = total
  end

  def on_start
    @progress.start
  end

  def on_increment
    @progress.increment
  end

  def on_finish
    @progress.finish
  end
end
