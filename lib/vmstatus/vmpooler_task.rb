require 'redis'

class Vmstatus::VmpoolerTask
  def initialize(opts)
    @host = opts[:host]
    @auth = opts[:auth]
  end

  def run(&block)
    with_redis(@host, @auth) do |redis|
      redis.keys('vmpooler__running__*').each do |key|
        redis.smembers(key).each do |hostname|
          url, checkout, lifetime, user, type = redis.hmget("vmpooler__vm__#{hostname}", 'tag:jenkins_build_url', 'checkout', 'lifetime', 'token:user', 'template')

          vmpooler_status = {
            :vmpooler => @host,
            :url      => url,
            :checkout => checkout,
            :lifetime => lifetime,
            :user     => user,
            :type     => type
          }

          # puts "#{hostname}, #{vmpooler_status}"
          yield hostname, vmpooler_status
        end
      end

      redis.keys('vmpooler__ready__*').each do |key|
        redis.smembers(key).each do |hostname|
          url, checkout, lifetime, user, type = redis.hmget("vmpooler__vm__#{hostname}", 'tag:jenkins_build_url', 'checkout', 'lifetime', 'token:user', 'template')

          vmpooler_status = {
            :vmpooler => @host,
            :url      => url,
            :checkout => checkout,
            :lifetime => lifetime,
            :user     => user,
            :type     => type
          }

          if url || checkout || user
            puts "Warning: ready vm #{hostname} in pooler #{@host} is in an unexpected state: #{vmpooler_status.inspect}"
          end

          yield hostname, vmpooler_status
        end
      end
    end
  end

  private

  def with_redis(host, auth)
    redis = Redis.new(:host => host)
    if auth.nil?
      puts "Redis connecting to #{host} without AUTH"
    else
      puts "Redis connecting to #{host} with auth set"
      redis.auth(auth)
    end
    begin
      yield redis
    ensure
      redis.close
    end
  end
end
