require 'active_support'
require 'active_model'
require 'rspec'

require File.expand_path("../../lib/stella.rb", __FILE__)

RSpec.configure do |config|
  config.mock_with :rspec do |c|
    c.syntax = :expect
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.raise_errors_for_deprecations!

  config.before(:context, elasticsearch: true) do
    Elasticsearch::Model.client = Elasticsearch::Client.new log: true
    Stella::Helpers.types.each { |type| type.__elasticsearch__.client = nil } # clear memoized clients
  end
end
