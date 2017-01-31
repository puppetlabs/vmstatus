class Vmstatus::Results
  attr_reader :state

  def initialize(vms)
    @vms = vms
    @state = vms.group_by { |vm| vm.job_status }

    %w(queued building disabled passed failed aborted deleted unknown adhoc ready orphaned).each do |state|
      @state[state] ||= []
    end
  end

  def vms
    @vms
  end

  def useful_count
    queued.count + building.count
  end

  def total_count
    @state.values.inject(0) { |sum, vms| sum + vms.count }
  end

  def queued
    @state['queued']
  end

  def building
    @state['building']
  end

  def disabled
    @state['disabled']
  end

  def passed
    @state['passed']
  end

  def failed
    @state['failed']
  end

  def aborted
    @state['aborted']
  end

  def deleted
    @state['deleted']
  end

  def unknown
    @state['unknown']
  end

  def orphaned
    @state['orphaned']
  end

  def adhoc
    @state['adhoc']
  end

  def ready
    @state['ready']
  end
end
