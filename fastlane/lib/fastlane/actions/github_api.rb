module Fastlane
  module Actions
    module SharedValues
      GITHUB_API_STATUS_CODE = :GITHUB_API_STATUS_CODE
      GITHUB_API_RESPONSE = :GITHUB_API_RESPONSE
      GITHUB_API_JSON = :GITHUB_API_JSON
    end

    class GithubApiAction < Action
      def self.run(params)
        require 'json'

        server = params[:server_url]
        http_method = (params[:http_method] || 'GET').to_s.upcase
        body = params[:body] || {}
        path = params[:path]
        url = File.join(server, path)
        headers = self.headers(params[:api_token])
        handled_errors = params[:errors] || {}

        if body.is_a?(Hash)
          request_json = body.to_json
        else
          UI.user_error!("Please provide valid JSON, or a hash as request body") unless parse_json(body)
          request_json = body
        end

        response = call_endpoint(
          url,
          http_method,
          headers,
          request_json,
          { secure: params[:secure], debug: params[:debug] }
        )

        status_code = response[:status]
        result = {
          status: status_code,
          response: response,
          json: parse_json(response.body) || {},
        }

        if status_code.between?(200, 299)
          if params[:debug]
            UI.message("Response:")
            UI.message(response.body)
            UI.message("---")
          end
          yield(result) if block_given?
        else
          if handled_error = handled_errors[status_code] || handled_errors['*']
            handled_error.call(result)
          else
            UI.error("---")
            UI.error("Request failed:\n#{http_method}: #{url}")
            UI.error("Headers:\n#{headers}")
            UI.error("---")
            UI.error("Response:")
            UI.error(response.body)
            UI.user_error!("GitHub responded with #{status_code}\n---\n#{response.body}")
          end
        end

        Actions.lane_context[SharedValues::GITHUB_API_STATUS_CODE] = result[:status]
        Actions.lane_context[SharedValues::GITHUB_API_RESPONSE] = result[:response]
        Actions.lane_context[SharedValues::GITHUB_API_JSON] = result[:json]

        return result
      end

      def self.headers(api_token)
        require 'base64'
        headers = { 'User-Agent' => 'fastlane-github_api' }
        headers['Authorization'] = "Basic #{Base64.strict_encode64(api_token)}" if api_token
        headers
      end

      def self.parse_json(value)
        begin
          JSON.parse(value)
        rescue JSON::ParserError => e
          nil
        end
      end

      def self.call_endpoint(url, http_method, headers, body, params = {})
        require 'excon'
        opts = {
          secure: true,
          debug: false
        }.merge(params)

        Excon.defaults[:ssl_verify_peer] = opts[:secure]
        middlewares = Excon.defaults[:middlewares] + [Excon::Middleware::RedirectFollower] # allow redirect in case of repo renames

        UI.message("#{http_method} : #{url}")

        connection = Excon.new(url)
        connection.request(
          method: http_method,
          headers: headers,
          middlewares: middlewares,
          body: body,
          debug_request: opts[:debug],
          debug_response: opts[:debug]
        )
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Call a Github API endpoint and get the resulting JSON response"
      end

      def self.details
        "Calls any Github API endpoint. You must provide your GitHub Personal token (get one from https://github.com/settings/tokens/new).
        Out parameters provide the status code and the full response JSON if valid, otherwise the raw response body.
        Documentation: https://developer.github.com/v3"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :server_url,
                                       env_name: "FL_GITHUB_API_SERVER_URL",
                                       description: "The server url. e.g. 'https://your.internal.github.host/api/v3' (Default: 'https://api.github.com')",
                                       default_value: "https://api.github.com",
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Please include the protocol in the server url, e.g. https://your.github.server/api/v3") unless value.include? "//"
                                       end),
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       env_name: "FL_GITHUB_API_TOKEN",
                                       description: "Personal API Token for GitHub - generate one at https://github.com/settings/tokens",
                                       sensitive: true,
                                       is_string: true,
                                       default_value: ENV["GITHUB_API_TOKEN"],
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :http_method,
                                       env_name: "FL_GITHUB_API_HTTP_METHOD",
                                       description: "The HTTP method. e.g. GET / POST",
                                       default_value: "GET",
                                       optional: true,
                                       verify_block: proc do |value|
                                        unless %w( GET POST PUT DELETE HEAD CONNECT ).include?(value.to_s.upcase)
                                          UI.user_error!("Unrecognised HTTP method")
                                        end
                                       end),
          FastlaneCore::ConfigItem.new(key: :body,
                                       env_name: "FL_GITHUB_API_REQUEST_BODY",
                                       description: "The request body in JSON or hash format",
                                       is_string: false,
                                       default_value: {},
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :path,
                                       env_name: "FL_GITHUB_API_PATH",
                                       description: "The endpoint path. e.g. '/repos/:owner/:repo/readme'",
                                       default_value: "https://api.github.com",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :errors,
                                       description: "Optional error handling hash based on status code, or pass '*' to handle all errors",
                                       is_string: false,
                                       default_value: {},
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :secure,
                                     env_name: "FL_GITHUB_API_SECURE",
                                     description: "Optionally disable secure requests (ssl_verify_peer)",
                                     is_string: false,
                                     default_value: true,
                                     optional: true),
          FastlaneCore::ConfigItem.new(key: :debug,
                                       env_name: "FL_GITHUB_API_DEBUG",
                                       description: "Github API debug option for output (true/false)",
                                       default_value: false,
                                       is_string: false)
        ]
      end

      def self.output
        [
          ['GITHUB_API_STATUS_CODE', 'The status code returned from the request'],
          ['GITHUB_API_RESPONSE', 'The full (excon) response object'],
          ['GITHUB_API_JSON', 'The raw json returned from Github']
        ]
      end

      def self.return_value
        "A hash including the HTTP status code (:status), the full (excon) response object (:response), and if valid JSON has been returned the parsed JSON (:json)."
      end

      def self.authors
        ["tommeier"]
      end

      def self.example_code
        [
          'result = github_api(
            server_url: "https://api.github.com",
            api_token: ENV["GITHUB_TOKEN"],
            http_method: "GET",
            path: "/repos/:owner/:repo/readme",
            body: { ref: "master" }
          )',
          '# Alternatively call directly with optional error handling or block usage
          GithubApiAction.run(
            server_url: "https://api.github.com",
            api_token: ENV["GITHUB_TOKEN"],
            http_method: "GET",
            path: "/repos/:owner/:repo/readme",
            errors: {
              404 => Proc.new do |result|
                UI.message("Something went wrong - I couldn\'t find it...")
              end,
              \'*\' => Proc.new do |result|
                UI.message("Handle all error codes other than 404")
              end
            }
          ) do |result|
            UI.message("JSON returned: #{result[:json]}")
          end
          '
        ]
      end

      def self.is_supported?(platform)
        true
      end

      def self.category
        :source_control
      end
    end
  end
end
