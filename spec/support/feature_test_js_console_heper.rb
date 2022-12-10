module FeatureTestJsConsoleHelper
  ##
  # @param this_page [Page] (optional) Page being tested via Capybara (uses global `page` if not given)
  # @param context: [\String] (optional) Context description to output within the error message
  # @param skip_errors: [\Proc] (optional)  Proc that you can use to filter out error messages you on't care about. Note: The default Capybara system will still print the JS errors to the rspec feature test output
  def expect_no_js_errors!(this_page = nil, context: nil, skip_errors: nil)
    this_page = page if this_page.nil?

    # page.driver.console_messages only works with apparition. If you use any other driver we need to skip it
    error_messages = fetch_js_window_errors(this_page, skip_errors)

    if error_messages.count > 0
      msg = error_messages.map do |e|
        e   = e.to_h.with_indifferent_access
        str = e[:message] ? e[:message].to_s : "*No error message provided*"
        if e[:line_number].present?
          str += " (on line #{ e[:line_number] }#"
          str += ":#{ e[:column_number] }" if e[:column_number].present?
          str += ")"
        end
        str
      end.join("\n")

      msg += " > CONTEXT: #{ context }" if context.present?

      if ENV['PRY_ON_ERROR'].to_bool
        debugger # rubocop:disable Lint/Debugger
        $pryed_on_error = true
      end

      raise JsError, msg
    end
  end

  def fetch_js_window_errors(this_page = nil, skip_errors = nil)
    this_page = page if this_page.nil?
    if this_page.driver.respond_to?(:console_messages)
      fetch_js_console_error_msgs(this_page, skip_errors)
    else
      this_page.evaluate_script('window.__errors || []').to_a
    end
  end

  ##
  #
  # page.driver.console_messages only works with apparition. If you use any other driver we need to skip it
  # check for JS errors, make sure there are none
  # this is just an assurance, as encountering a JS error should cause apparition to fail the test.
  def fetch_js_console_error_msgs(this_page = nil, skip_errors = nil)
    this_page ||= page
    this_page.driver.console_messages.select do |msg|
      msg.type == "error" && (!skip_errors.is_a?(Proc) || skip_errors.call(msg))
    end
  end
end

RSpec.configure do |c|
  c.include FeatureTestJsConsoleHelper
end
