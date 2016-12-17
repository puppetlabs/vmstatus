require 'date'
require 'time'

class Vmstatus::VM
  attr_reader :name, :url, :type, :user, :checkout, :ttl

  def initialize(name, options)
    @name = name
    @type = options[:type]
    @url = options[:url]
    @checkout = options[:checkout]
    if @checkout && options[:lifetime]
      expiration = DateTime.parse(@checkout) + (Integer(options[:lifetime]) / 24.0)
      @ttl = (expiration.to_time - Time.now) / 60.0 / 60.0 # hours
    else
      @ttl = -1
    end
    @user = options[:user] || 'unknown'
  end

  def running=(time, value, reason)
    if value
      @running = value
    else
      #puts "Failed to connect to #{@name}"
    end
  end

  def running?
    @running
  end

  def status=(time, value, reason)
    if value
      @status = value
    else
      #puts "Failed to get status from #{@url}: #{reason}"
      @status = 'unknown'
    end
  end

  def status
    @status
  end

  def to_s
    @name
  end
end
