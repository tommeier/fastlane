describe Fastlane do
  describe Fastlane::FastFile do
    describe "github_api" do
      let(:response_body) { File.read("./fastlane/spec/fixtures/requests/github_create_file_response.json") }

      context 'successful' do
        before do
          stub_request(:put, "https://api.github.com/repos/fastlane/fastlane/contents/TEST_FILE.md").
            with(headers: {
                    'Authorization' => 'Basic MTIzNDU2Nzg5',
                    'Host' => 'api.github.com:443',
                    'User-Agent' => 'fastlane-github_api'
                  }).
            to_return(status: 200, body: response_body, headers: {})
        end

        context 'with a hash body' do
          it 'correctly submits to github api' do
            result = Fastlane::FastFile.new.parse("
              lane :test do
                github_api(
                  api_token: '123456789',
                  http_method: 'PUT',
                  path: 'repos/fastlane/fastlane/contents/TEST_FILE.md',
                  body: {
                    path: 'TEST_FILE.md',
                    message: 'File committed',
                    content: 'VGVzdCBDb250ZW50Cg==\n',
                    branch: 'test-branch'
                  }
                )
              end
            ").runner.execute(:test)

            expect(result[:status]).to eq(200)
            expect(result[:response]).to be_a(Excon::Response)
            expect(result[:response].body).to eq(response_body)
            expect(result[:json]).to eq(JSON.parse(response_body))
          end
        end

        context 'with raw JSON body' do
          it 'correctly submits to github api' do
            result = Fastlane::FastFile.new.parse(%{
              lane :test do
                github_api(
                  api_token: '123456789',
                  http_method: 'PUT',
                  path: 'repos/fastlane/fastlane/contents/TEST_FILE.md',
                  body: '{
                      "path":"TEST_FILE.md",
                      "message":"File committed",
                      "content":"VGVzdCBDb250ZW50Cg==\\\\n",
                      "branch":"test-branch"
                    }'
                  )
              end
            }).runner.execute(:test)

            expect(result[:status]).to eq(200)
            expect(result[:response]).to be_a(Excon::Response)
            expect(result[:response].body).to eq(response_body)
            expect(result[:json]).to eq(JSON.parse(response_body))
          end
        end

        it 'allows calling as a block for success from other actions' do
          expect do
            Fastlane::FastFile.new.parse(%{
              lane :test do
                Fastlane::Actions::GithubApiAction.run(
                  server_url: 'https://api.github.com',
                  api_token: '123456789',
                  http_method: 'PUT',
                  path: 'repos/fastlane/fastlane/contents/TEST_FILE.md',
                  body: '{
                      "path":"TEST_FILE.md",
                      "message":"File committed",
                      "content":"VGVzdCBDb250ZW50Cg==\\\\n",
                      "branch":"test-branch"
                    }'
                  ) do |result|
                    UI.user_error!("Success block triggered with \#{result[:response].body}")
                  end
              end
            }).runner.execute(:test)
          end.to(
            raise_error(FastlaneCore::Interface::FastlaneError) do |error|
              expect(error.message).to match("Success block triggered with #{response_body}")
            end
          )
        end

        context 'optional params' do
          let(:response_body) { File.read("./fastlane/spec/fixtures/requests/github_upload_release_asset_response.json") }
          let(:headers) { {
            'Authorization' => 'Basic MTIzNDU2Nzg5',
            'Host' => 'uploads.github.com:443',
            'User-Agent'=>'fastlane-github_api'
          } }

          before do
            stub_request(:post, "https://uploads.github.com/repos/fastlane/fastlane/releases/1/assets?name=TEST_FILE.md").
            with(body: "test raw content of file",
                 headers: headers).
            to_return(status: 200, body: response_body, headers: {})
          end

          context 'full url and raw body' do
            it 'allows overrides and sends raw full values' do
              result = Fastlane::FastFile.new.parse(%{
                lane :test do
                  github_api(
                    api_token: '123456789',
                    http_method: 'POST',
                    url: 'https://uploads.github.com/repos/fastlane/fastlane/releases/1/assets?name=TEST_FILE.md',
                    raw_body: 'test raw content of file'
                    )
                end
              }).runner.execute(:test)

              expect(result[:status]).to eq(200)
              expect(result[:response]).to be_a(Excon::Response)
              expect(result[:response].body).to eq(response_body)
              expect(result[:json]).to eq(JSON.parse(response_body))
            end
          end

          context 'overridable headers' do
            let(:headers) { {
              'Authorization' => 'custom',
              'Host' => 'uploads.github.com:443',
              'User-Agent' => 'fastlane-github_api',
              'Content-Type' => 'text/plain'
            } }

            it 'allows calling with custom headers and override auth' do
              result = Fastlane::FastFile.new.parse(%{
                lane :test do
                  github_api(
                    api_token: '123456789',
                    http_method: 'POST',
                    headers: {
                      'Content-Type' => 'text/plain',
                      'Authorization' => 'custom'
                    },
                    url: 'https://uploads.github.com/repos/fastlane/fastlane/releases/1/assets?name=TEST_FILE.md',
                    raw_body: 'test raw content of file'
                    )
                end
              }).runner.execute(:test)

              expect(result[:status]).to eq(200)
              expect(result[:response]).to be_a(Excon::Response)
              expect(result[:response].body).to eq(response_body)
              expect(result[:json]).to eq(JSON.parse(response_body))
            end
          end
        end
      end

      context 'failures' do
        let(:error_response_body) { '{"message":"Bad credentials","documentation_url":"https://developer.github.com/v3"}' }

        before do
          stub_request(:put, "https://api.github.com/repos/fastlane/fastlane/contents/TEST_FILE.md").
            with(headers: {
                    'Authorization' => 'Basic MTIzNDU2Nzg5',
                    'Host' => 'api.github.com:443',
                    'User-Agent' => 'fastlane-github_api'
                  }).
            to_return(status: 401, body: error_response_body, headers: {})
        end

        it "raises on error by default" do
          expect do
            Fastlane::FastFile.new.parse("
              lane :test do
                github_api(
                  api_token: '123456789',
                  http_method: 'PUT',
                  path: 'repos/fastlane/fastlane/contents/TEST_FILE.md',
                  body: {
                    path: 'TEST_FILE.md',
                    message: 'File committed',
                    content: 'VGVzdCBDb250ZW50Cg==\n',
                    branch: 'test-branch'
                  }
                )
              end
            ").runner.execute(:test)
          end.to(
            raise_error(FastlaneCore::Interface::FastlaneError) do |error|
              expect(error.message).to match("GitHub responded with 401")
            end
          )
        end

        it "allows custom error handling by status code" do
          expect do
            Fastlane::FastFile.new.parse("
              lane :test do
                github_api(
                  api_token: '123456789',
                  http_method: 'PUT',
                  path: 'repos/fastlane/fastlane/contents/TEST_FILE.md',
                  body: {
                    path: 'TEST_FILE.md',
                    message: 'File committed',
                    content: 'VGVzdCBDb250ZW50Cg==\n',
                    branch: 'test-branch'
                  },
                  errors: {
                    401 => proc {|result|
                      UI.user_error!(\"Custom error handled for 401 \#{result[:response].body}\")
                    },
                    404 => proc do |result|
                      UI.message('not found')
                    end
                  }
                )
              end
            ").runner.execute(:test)
          end.to(
            raise_error(FastlaneCore::Interface::FastlaneError) do |error|
              expect(error.message).to match("Custom error handled for 401 #{error_response_body}")
            end
          )
        end

        it "allows custom error handling for all other errors" do
          expect do
            Fastlane::FastFile.new.parse("
              lane :test do
                github_api(
                  api_token: '123456789',
                  http_method: 'PUT',
                  path: 'repos/fastlane/fastlane/contents/TEST_FILE.md',
                  body: {
                    path: 'TEST_FILE.md',
                    message: 'File committed',
                    content: 'VGVzdCBDb250ZW50Cg==\n',
                    branch: 'test-branch'
                  },
                  errors: {
                    '*' => proc do |result|
                      UI.user_error!(\"Custom error handled for all errors\")
                    end,
                    404 => proc do |result|
                      UI.message('not found')
                    end
                  }
                )
              end
            ").runner.execute(:test)
          end.to(
            raise_error(FastlaneCore::Interface::FastlaneError) do |error|
              expect(error.message).to match("Custom error handled for all errors")
            end
          )
        end

        it "doesn't raise on custom error handling" do
          result = Fastlane::FastFile.new.parse("
            lane :test do
              github_api(
                api_token: '123456789',
                http_method: 'PUT',
                path: 'repos/fastlane/fastlane/contents/TEST_FILE.md',
                body: {
                  path: 'TEST_FILE.md',
                  message: 'File committed',
                  content: 'VGVzdCBDb250ZW50Cg==\n',
                  branch: 'test-branch'
                },
                errors: {
                  401 => proc do |result|
                    UI.message(\"error handled\")
                  end
                }
              )
            end
          ").runner.execute(:test)

          expect(result[:status]).to eq(401)
          expect(result[:response]).to be_a(Excon::Response)
          expect(result[:response].body).to eq(error_response_body)
          expect(result[:json]).to eq(JSON.parse(error_response_body))
        end

        it "raises when path and url aren't set" do
          expect do
            Fastlane::FastFile.new.parse("
              lane :test do
                github_api(
                  api_token: '123456789',
                  http_method: 'PUT',
                )
              end
            ").runner.execute(:test)
          end.to(
            raise_error(FastlaneCore::Interface::FastlaneError) do |error|
              expect(error.message).to match("Please provide either 'path' or full 'url' for github api endpoint")
            end
          )
        end
      end
    end
  end
end
