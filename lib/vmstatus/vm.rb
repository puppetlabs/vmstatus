require 'date'
require 'time'

class Vmstatus::VM
  attr_reader :hostname, :url, :type, :user, :checkout, :ttl

  def initialize(hostname, options)
    @hostname = hostname
    @type = options[:type]
    @url = options[:url]
    @ttl = -1
    if options[:checkout]
      @checkout = DateTime.parse(options[:checkout])
      if options[:lifetime]
        expiration = @checkout + (Integer(options[:lifetime]) / 24.0)
        @ttl = (expiration.to_time - Time.now) / 60.0 / 60.0 # hours
      end
    end
    @user = options[:user] || 'unknown'
  end

  def running=(time, value, reason)
    if value
      @running = value
    else
      #puts "Failed to connect to #{@hostname}"
    end
  end

  def running?
    @running
  end

  def job_status=(time, value, reason)
    if value
      @job_status = value
    else
      #puts "Failed to get job status from #{@url}: #{reason}"
      @job_status = 'unknown'
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

  def to_s
    @hostname
  end
end
