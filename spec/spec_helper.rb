# Enable these lines to print a coverage report after the test suite completes.
# require 'simplecov'
# SimpleCov.start 'rails'

ENV["RAILS_ENV"] = 'test'

require 'capybara'
require 'capybara/mechanize'
require 'rspec'
require 'capybara/rspec'
require 'active_support'
require 'to_bool'
require 'rainbow'
require 'pry'
require 'pry-remote'
require 'bundler/setup'

# Webmock allows us to mock responses from external requests by specifying a URL
# @see spec/factories/store_factory.rb for example usage
require 'webmock/rspec'
# By default WbeMock will disallow any http requests. Since we're doing lots of feature tests that need to do
# HTTP requests, we need to allow them all by default.
WebMock.allow_net_connect!
include WebMock::API # rubocop:disable Style/MixinUsage

# Supports :chrome or :firefox here
BROWSER = :chrome

# For parallel testing we need to set the capybara port based on the opts
capybara_server_port = 3008 + ENV['TEST_ENV_NUMBER'].to_i

# Setup the example web server
require File.expand_path('../example_server.rb', __dir__)
Capybara.register_server :thin do |app, port, host, **options|
  begin
    require 'rack/handler/thin'
  rescue LoadError
    raise LoadError, "Capybara is unable to load `thin` for its server, please add `thin` to your project or specify a different server via something like `Capybara.server = :webrick`."
  end

  Thin::Logging.silent = options.delete(:Silent)

  puts "Starting Thin on #{ host }:#{ port }"

  Rack::Handler::Thin.run(app, { Port: port, Host: host, signals: false }.merge(options))
end

Capybara.configure do |config|
  config.app = ExampleServer.new # Thin app
  config.server = :thin
  config.default_max_wait_time = ENV.fetch('FEATURE_TEST_MAX_WAIT_TIME', 60).to_i
  config.asset_host = "http://127.0.0.1:#{ capybara_server_port }"
  config.server_host = '127.0.0.1'
  config.server_port = capybara_server_port
end

# If AWS is enabled, uncomment these lines
# require "aws-sdk"
# Aws.config[:s3] = { stub_responses: true } if defined?(Aws) && Aws.config.present?

# Enable sidekiq testing functionality. Note that once we do this, the testing library
# will change how the ENTIRE sidekiq queueing system works. As such, we need to disable
# testing mode straight away in order to preserve normal sidekiq functionality.
# We can re-enable testing mode in each test that needs it.
# require 'sidekiq/testing'
# Sidekiq::Testing.disable!

Capybara.default_max_wait_time = ENV.fetch('FEATURE_TEST_MAX_WAIT_TIME', 15).to_i
if ENV['FEATURE_TEST_MAX_WAIT_TIME'].present?
  puts "Will wait up to #{ ENV['FEATURE_TEST_MAX_WAIT_TIME'] } for feature tests to complete before deeming them a failure."
end

Selenium::WebDriver.logger.level = :debug if ENV['SELENIUM_DEBUG_MODE'].to_bool

CAPYBARA_DOWNLOAD_DIRECTORY = ['tmp', "test#{ ENV.fetch('TEST_ENV_NUMBER', nil) }", 'capybara', 'downloads'].join("/")
FileUtils.mkdir_p(CAPYBARA_DOWNLOAD_DIRECTORY) # This will make the directory if it does not exist

#############################################################################################
# BEGIN - Browser setup for feature tests

if BROWSER == :chrome
  require 'capybara/apparition'

  Capybara.register_driver :apparition_headless do |app|
    Capybara::Apparition::Driver.new(app, { headless: true, window_size: [1366, 768], timeout: 120, js_errors: true, ignore_https_errors: true })
  end

  Capybara.register_driver :apparition do |app|
    browser_options = { 'enable-features'      => 'NetworkService,NetworkServiceInProcess',
                        'disable-gpu'          => nil,
                        'no-sandbox'           => nil,
                        'disable-web-security' => nil,
                        'disable-features'     => 'VizDisplayCompositor', }

    Capybara::Apparition::Driver.new(app, inspector: true, headless: false, window_size: [1366, 768], timeout: 120,
                                     js_errors: true, debug: true, ignore_https_errors: true, browser_options: browser_options)
  end

  Capybara.javascript_driver = (ENV['DEBUG'].to_bool || ENV['HEADLESS'] == 'false') ? :apparition : :apparition_headless
  Capybara.default_driver = (ENV['DEBUG'].to_bool || ENV['HEADLESS'] == 'false') ? :apparition : :apparition_headless
else
  if ENV['FIREFOX_BROWSER_PATH'].present?
    Selenium::WebDriver::Firefox.path = ENV['FIREFOX_BROWSER_PATH']
    puts "Using Firefox from: #{ ENV['FIREFOX_BROWSER_PATH'] }"
  end

  firefox_profile = Selenium::WebDriver::Firefox::Profile.new
  firefox_profile['browser.download.dir'] = CAPYBARA_DOWNLOAD_DIRECTORY
  firefox_profile['browser.download.folderList'] = 2
  firefox_profile['browser.helperApps.alwaysAsk.force'] = false
  firefox_profile['network.websocket.allowInsecureFromHTTPS'] = true # Since capybara runs on http://
  firefox_profile['network.cookie.sameSite.laxByDefault'] = false
  firefox_profile['network.cookie.sameSite.noneRequiresSecure'] = false
  firefox_profile['browser.download.manager.showWhenStarting'] = false
  firefox_profile["browser.download.viewableInternally.enabledTypes"] = ""
  firefox_profile["devtools.selfxss.count"] = 100 # To allow pasting in dev tools when we open the console
  firefox_profile['browser.helperApps.neverAsk.saveToDisk'] =
    'text/csv,text/tsv,text/xml,application/xml,text/plain,application/pdf,application/doc,application/docx,' \
    'image/jpeg,application/gzip,application/x-gzip,application/octet-stream,image/png,image/jpg'
  firefox_browser_options = ::Selenium::WebDriver::Firefox::Options.new
  firefox_browser_options.profile = firefox_profile

  Capybara.register_driver :selenium do |app|
    Capybara::Selenium::Driver.new(app, browser: :firefox, timeout: 120, options: firefox_browser_options)
  end

  Capybara.register_driver :selenium_headless do |app|
    Capybara::Selenium::Driver.load_selenium
    firefox_browser_options.args << '-headless'
    Capybara::Selenium::Driver.new(app, browser: :firefox, timeout: 120, options: firefox_browser_options)
  end

  Capybara.javascript_driver = (ENV['DEBUG'].to_bool || ENV['HEADLESS'] == 'false') ? :selenium : :selenium_headless
  Capybara.default_driver = (ENV['DEBUG'].to_bool || ENV['HEADLESS'] == 'false') ? :selenium : :selenium_headless
end

#############################################################################################
# END - Browser setup for feature tests

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir["support/**/*.rb"].sort.each { |f| require f }

# This is helpful for chaining `.and` although should be used sparingly to avoid confusion (see https://github.com/rspec/rspec-expectations/issues/493)
RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.configure do |config|
  config.after do |example|
    next if !example.exception || $pryed_on_error

    if ENV['DEBUG'].to_bool || ENV['PRY_ON_ERROR'].to_bool
      puts Rainbow("[DEBUG MODE] Test failed:\n").red + example.exception.inspect
      binding.pry # rubocop:disable Lint/Debugger
    elsif ENV['ENABLE_SENTRY_FOR_TEST'].to_bool && ENV['HEROKU_TEST_RUN_BRANCH'] == 'master' && defined?(Raven)
      Raven.capture_exception(example.exception, extra: example.metadata.to_h.slice(:file_path, :line_number, :full_description))
    end
  end

  # Setup screen shot system
  if ENV['SCREENSHOTS'].to_bool
    $screenshots_folder = 'log/test/screenshots'

    if ENV['TEST_ENV_NUMBER']
      $screenshots_folder += "parallel_spec-#{ ENV['TEST_ENV_NUMBER'].to_i }"
    end

    $screenshot_test_sequence = 0
    FileUtils.rm_rf($screenshots_folder)
    FileUtils.mkdir_p($screenshots_folder) # Ensure screenshot folder is cleared and existing
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = [:should, :expect]
  end

  config.after(:suite) do
    FileUtils.rm_rf(Dir["tmp/test/uploads"])
  end

  config.color = true
end
