class Vmstatus::Results
  attr_reader :state

  def initialize(vms)
    @state = {
      :ready => [],
      :queued => [],
      :ok => [],
      :missing => [],
      :disabled => [],
      :passed => [],
      :zombie => [],
      :failed => [],
      :aborted => [],
      :deleted => [],
      :unknown_running => [],
      :unknown_dead => [],
    }

    vms.each do |vm|
      case vm.job_status
      when 'queued'
        if vm.running?
          state[:ready] << vm
        else
          state[:queued] << vm
        end
      when 'building'
        if vm.running?
          state[:ok] << vm
        else
          state[:missing] << vm
        end
      when 'disabled'
        state[:disabled] << vm
      when 'passed'
        if vm.running?
          state[:passed] << vm
        else
          state[:zombie] << vm
        end
      when 'failed'
        if vm.running?
          state[:failed] << vm
        else
          state[:zombie] << vm
        end
      when 'aborted'
        if vm.running?
          state[:aborted] << vm
        else
          state[:zombie] << vm
        end
      when 'deleted'
        if vm.running?
          state[:deleted] << vm
        else
          state[:zombie] << vm
        end
      else
        if vm.running?
          state[:unknown_running] << vm
        else
          state[:unknown_dead] << vm
        end
      end
    end
  end
end
