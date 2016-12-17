require 'json'
require 'rest-client'

class Vmstatus::JenkinsTask
  def initialize(url)
    @url = url
  end

  def run
    if @url =~ /https?:\/\/jenkins.*/
      # hack since cinext tags don't include the build number
      if @url =~ /\/\d+\/$/
        job_url = @url.sub(/\d+\/$/, '') + "api/json"
        build_url = @url + "api/json"
      else
        job_url = @url + "api/json"
        build_url = "#{@url}lastBuild/api/json"
      end

      #puts "job_url #{job_url}"
      #puts "build_url #{build_url}"

      job_status = JSON.parse(RestClient.get(job_url))

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
        last_build_status = JSON.parse(RestClient.get(build_url))
        if last_build_status['result'] == 'SUCCESS'
          'passed'
        else
          'failed'
        end
      end
    else
      'none'
    end
  end
end

