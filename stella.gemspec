$:.unshift File.expand_path("../lib", __FILE__)
require 'stella/version'

Gem::Specification.new do |gem|
  gem.name = "stella"
  gem.homepage = "https://github.com/artsy/stella"
  gem.license = "MIT"
  gem.summary = %Q{Make your Ruby objects searchable with Elasticsearch.}
  gem.version = Stella::VERSION
  gem.description = 'Make your Ruby objects searchable with Elasticsearch.'
  gem.email = ["anil@artsy.net"]
  gem.authors = ["Anil Bawa-Cavia", "Matt Zikherman"]

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- spec/*`.split("\n")

  gem.add_runtime_dependency 'elasticsearch-model'
  gem.add_runtime_dependency 'activesupport'
  gem.add_runtime_dependency 'activemodel'

  gem.add_development_dependency 'activerecord'
  gem.add_development_dependency 'rspec', '~> 3.1.0'
  gem.add_development_dependency 'rspec-expectations'
  gem.add_development_dependency 'sqlite3'
  gem.add_development_dependency 'rubocop', '0.46.0'
end
