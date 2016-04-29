module FastlaneCore
  class ToolCollector
    TOOLS = %w(fastlane fastlane_core deliver snapshot frameit pem sigh produce cert gym pilot credentials_manager spaceship scan supply watchbuild match screengrab)
    HOST_URL = "https://fastlane-enhancer.herokuapp.com/"

    attr_reader :error

    def did_launch_action(name)
      if is_official?(name)
        launches[name] ||= 0
        launches[name] += 1
      end
    end

    def did_raise_error(name)
      if is_official?(name)
        @error = name
      end
    end

    # Sends the used actions
    # Example data => [:xcode_select, :deliver, :notify, :slack]
    def did_finish
      return if ENV["FASTLANE_OPT_OUT_USAGE"]
      if !did_show_message? and !Helper.is_ci?
        UI.message("Sending Crash/Success information. More information on: https://github.com/fastlane/enhancer")
        UI.message("No personal/sensitive data is sent. Only sharing the following:")
        UI.message(launches)
        UI.message(@error) if @error
        UI.message("This information is used to fix failing actions and improve integrations that are often used.")
        UI.message("You can disable this by adding `opt_out_usage` to your Fastfile")
      end

      require 'excon'
      url = HOST_URL + '/did_launch?'
      url += URI.encode_www_form(
        steps: launches.to_json,
        error: @error
      )

      if Helper.is_test? # don't send test data
        return url
      else
        fork do
          begin
            Excon.post(url)
          rescue
            # we don't want to show a stack trace if something goes wrong
          end
        end
      end
    rescue
      # We don't care about connection errors
    end

    def launches
      @launches ||= {}
    end

    def is_official?(name)
      return TOOLS.include?(name.to_s)
    end

    def did_show_message?
      path = File.join(File.expand_path('~'), '.did_show_opt_info')

      did_show = File.exist? path
      File.write(path, '1')
      did_show
    end
  end
end
