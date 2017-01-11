require 'json'
require 'rest-client'

class Vmstatus::JenkinsTask
  # limit jenkins queries for perf reasons
  JOB_PARAMS = %w(buildable color inQueue)
  BUILD_PARAMS = %w(result)
  USER_AGENT = "vmstatus/#{Vmstatus::VERSION}"

  def initialize(url)
    @url = url
  end

  def run
    if @url =~ /https?:\/\/jenkins.*/
      # hack since cinext tags only recently included the build number
      if @url =~ /\/\d+\/$/
        job_url = @url.sub(/\d+\/$/, '') + "api/json"
        build_url = @url + "api/json"
      else
        job_url = @url + "api/json"
        build_url = "#{@url}lastBuild/api/json"
      end

      #puts "job_url #{job_url}"
      #puts "build_url #{build_url}"

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
        last_build_status = JSON.parse(RestClient.get(build_url, params: {tree: BUILD_PARAMS.join(',')}, :user_agent => USER_AGENT))
        result = last_build_status['result']
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
    else
      'none'
    end
  end
end

