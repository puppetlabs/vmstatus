require 'json'
require 'rest-client'

class Vmstatus::JenkinsTask
  # limit jenkins queries for perf reasons
  JOB_PARAMS = %w(buildable color inQueue)
  BUILD_PARAMS = %w(result)
  USER_AGENT = "vmstatus/#{Vmstatus::VERSION}"

  def initialize(vm)
    @vm = vm
  end

  def run
    # hack since cinext tags only recently included the build number
    if @vm.url =~ /\/\d+\/$/
      job_url = @vm.url.sub(/\d+\/$/, '') + "api/json"
      build_url = @vm.url + "api/json"
    else
      job_url = @vm.url + "api/json"
      build_url = "#{@vm.url}lastBuild/api/json"
    end

    #puts "job_url #{job_url}"
    #puts "build_url #{build_url}"

    begin
      job_status = JSON.parse(RestClient.get(job_url, params: {tree: JOB_PARAMS.join(',')}, :user_agent => USER_AGENT))

      if job_status['inQueue']
        'queued'
      elsif !job_status['buildable']
        'disabled'
      elsif job_status['color'] =~ /anime/
        'building'
      elsif job_status['color'] == 'notbuilt'
        'failed' # never run before
      else
        # not every job has a lastBuild
        build_status = JSON.parse(RestClient.get(build_url, params: {tree: BUILD_PARAMS.join(',')}, :user_agent => USER_AGENT))
        result = build_status['result']
        case result
        when 'SUCCESS'
          'passed'
        when 'ABORTED'
          'aborted'
        when 'UNSTABLE', 'NOT_BUILT', 'FAILURE'
          'failed'
        else
          raise ArgumentError.new("Unknown jenkins build result: #{result}")
        end
      end
    rescue RestClient::NotFound
      'deleted'
    end
  end
end

