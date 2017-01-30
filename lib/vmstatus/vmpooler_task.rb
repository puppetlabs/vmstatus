require 'redis'

class Vmstatus::VmpoolerTask
  def initialize(host)
    @host = host
  end

  def run(vms, &block)
    with_redis(@host) do |redis|
      # which running VMs are in redis?
      vms.each_pair do |hostname, vm|
        url, checkout, lifetime, user, type = redis.hmget("vmpooler__vm__#{hostname}", 'tag:jenkins_build_url', 'checkout', 'lifetime', 'token:user', 'template')

        # redis returns a hash whose values are empty if the key doesn't exist,
        # but type is required, so if it's missing, then the key didn't exist.
        if type.nil?
          yield nil
        else
          options = {
            :type => type
          }

          if checkout
            options.merge!(
              {
                :url => url,
                :checkout => checkout,
                :lifetime => lifetime,
                :user => user
              }
            )
          end

          vm.vmpooler_status = options

          yield vm
        end
      end
    end
  end

  private

  def with_redis(host)
    redis = Redis.new(:host => host)
    begin
      yield redis
    ensure
      redis.close
    end
  end
end
