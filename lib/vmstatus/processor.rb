require 'concurrent'
require 'set'

require 'vmstatus/vm'
require 'vmstatus/inventory'
require 'vmstatus/ping_task'
require 'vmstatus/jenkins_task'
require 'vmstatus/vmpooler_task'
require 'vmstatus/results'

class Vmstatus::Processor
  def initialize(vsphere, vmpoolers, observer)
    @vsphere = vsphere
    @vmpoolers = vmpoolers
    @observer = observer
  end

  def process
    futures = Array.new

    inventory = @vsphere.inventory

    # estimate the total task count (2 tasks per vm)
    puts "Processing #{inventory.vms.count} VMs, ignoring #{inventory.template_count} templates"
    @observer.on_total(inventory.vms.count * (2 + @vmpoolers.count))

    # lookup vmpooler metadata first, since the jenkins task relies on it
    @vmpoolers.each do |vmpooler|
      future = Concurrent::Future.execute do
        task = Vmstatus::VmpoolerTask.new(vmpooler)
        task.run(inventory.vms) do |vm|
          @observer.on_increment

          if vm
            future = Concurrent::Future.new do
              task = Vmstatus::PingTask.new(vm.hostname, 22)
              task.run
            end
            future.add_observer(vm, :running=)
            future.add_observer(@observer, :on_increment)
            futures << future
            future.execute

            future = Concurrent::Future.new do
              task = Vmstatus::JenkinsTask.new(vm)
              task.run
            end
            future.add_observer(vm, :job_status=)
            future.add_observer(@observer, :on_increment)
            futures << future
            future.execute
          end
        end
      end
      futures << future
    end

    futures.each do |future|
      future.wait
    end

    Vmstatus::Results.new(inventory.vms.values)
  ensure
    futures.each { |future| future.delete_observers }
  end
end
