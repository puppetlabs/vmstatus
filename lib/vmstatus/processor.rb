require 'set'
require 'concurrent'

require 'vmstatus/vm'
require 'vmstatus/ping_task'
require 'vmstatus/jenkins_task'
require 'vmstatus/results'

class Vmstatus::Processor
  def initialize(observer)
    @observer = observer
    @completed_tasks = Concurrent::AtomicFixnum.new
  end

  def process(redis)
    vms = Set.new
    futures = []

    # estimate the total task count (2 tasks per vm)
    vm_count = running_count(redis)
    puts "Processing #{vm_count} VMs"
    @observer.on_total(2 * vm_count)
    @observer.on_start

    redis.keys('vmpooler__running__*').each do |key|
      redis.smembers(key).each do |hostname|
        type = key.sub(/vmpooler__running__/, '')
        url, checkout, lifetime, user = redis.hmget("vmpooler__vm__#{hostname}", 'tag:jenkins_build_url', 'checkout', 'lifetime', 'token:user')

        options = {
          :type => type,
          :url => url,
          :checkout => checkout,
          :lifetime => lifetime,
          :user => user
        }
        vm = Vmstatus::VM.new(hostname, options)
        vms.add(vm)

        future = Concurrent::Future.execute do
          task = Vmstatus::PingTask.new(vm.hostname, 22)
          task.run
        end
        future.add_observer(vm, :running=)
        future.add_observer(self, :on_task_complete)
        futures << future

        future = Concurrent::Future.execute do
          task = Vmstatus::JenkinsTask.new(vm.url)
          task.run
        end
        future.add_observer(vm, :job_status=)
        future.add_observer(self, :on_task_complete)
        futures << future
      end
    end

    # update total now that we have an exact count
    @observer.on_total(futures.count)

    futures.each do |future|
      future.wait
    end

    @observer.on_finish

    Vmstatus::Results.new(vms)
  ensure
    futures.each { |future| future.delete_observers }
  end

  def on_task_complete(time, value, reason)
    count = @completed_tasks.increment

    @observer.on_progress(count)
  end

  def running_count(redis)
    redis.keys('vmpooler__running__*').inject(0) do |sum, key|
      sum + redis.scard(key)
    end
  end
end
