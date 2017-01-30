require 'date'
require 'time'

class Vmstatus::VM
  attr_reader :hostname, :uuid, :url, :type, :user, :checkout, :ttl

  def initialize(hostname, uuid, on)
    @hostname = hostname
    @uuid = uuid
    @on = on
    @job_status = 'orphaned' # assume vm is not referenced by any vmpooler
  end

  def running=(time, value, reason)
    if value
      @running = value
    else
      #$stderr.puts "Failed to connect to #{@hostname}: #{reason} (#{reason.class})"
    end
  end

  def on?
    @on
  end

  def running?
    @running
  end

  def job_status=(time, value, reason)
    if value
      @job_status = value
    else
      #$stderr.puts "Failed to get job status for #{@hostname}: #{reason}"
    end
  end

  def job_status
    @job_status
  end

  def job_name
    if url.nil?
      ''
    elsif data = url.match(/.*\/job\/([^\/]+)/)
      data[1]
    else
      url
    end
  end

  def vmpooler_status=(options)
    @type = options[:type]
    @url = options[:url]
    if options[:checkout]
      @checkout = DateTime.parse(options[:checkout])
      if options[:lifetime]
        expiration = @checkout + (Integer(options[:lifetime]) / 24.0)
        @ttl = (expiration.to_time - Time.now) / 60.0 / 60.0 # hours
      end
    end
    @user = options[:user] || ''
  end

  def to_s
    @hostname
  end
end
