require 'active_support'
require 'active_model'
require 'rspec'

require 'coveralls'
Coveralls.wear!

require File.expand_path('../lib/estella.rb', __dir__)

RSpec.configure do |config|
  config.raise_errors_for_deprecations!

  config.before(:context, elasticsearch: true) do
    Elasticsearch::Model.client = Elasticsearch::Client.new
    Estella::Helpers.types.each { |type| type.__elasticsearch__.client = nil } # clear memoized clients
  end
end
