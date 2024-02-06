$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'estella/version'

Gem::Specification.new do |gem|
  gem.name = 'estella'
  gem.homepage = 'https://github.com/artsy/estella'
  gem.license = 'MIT'
  gem.summary = %(Make your Ruby objects searchable with Elasticsearch.)
  gem.version = Estella::VERSION
  gem.description = 'Make your Ruby objects searchable with Elasticsearch.'
  gem.email = ['anil@artsy.net']
  gem.authors = ['Anil Bawa-Cavia', 'Matt Zikherman']

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- spec/*`.split("\n")

  gem.add_runtime_dependency 'activemodel'
  gem.add_runtime_dependency 'activesupport'
  gem.add_runtime_dependency 'elasticsearch-model', '~> 7.0'

  gem.add_development_dependency 'activerecord'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'rake', '>= 12.3.3'
  gem.add_development_dependency 'rspec', '>= 3.5'
  gem.add_development_dependency 'rspec-expectations'
  gem.add_development_dependency 'rubocop', '1.31.1'
  gem.add_development_dependency 'sqlite3'
end
