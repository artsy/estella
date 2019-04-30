# estella

[![Gem Version](https://badge.fury.io/rb/estella.svg)](https://badge.fury.io/rb/estella)
[![Build Status](https://travis-ci.org/artsy/estella.svg?branch=master)](https://travis-ci.org/artsy/estella)
[![License Status](https://git.legal/projects/3493/badge.svg)](https://git.legal/projects/3493)
[![Coverage Status](https://coveralls.io/repos/github/artsy/estella/badge.svg?branch=master)](https://coveralls.io/github/artsy/estella?branch=master)

Builds on [elasticsearch-model](https://github.com/elastic/elasticsearch-rails/tree/master/elasticsearch-model) to make your Ruby objects searchable with Elasticsearch. Provides fine-grained control of fields, analysis, filters, weightings and boosts.

## Compatibility

This library is compatible with [Elasticsearch 1.5.x, 2.x](https://www.elastic.co/products/elasticsearch) and currently does not work with Elasticsearch 5.x (see [#18](https://github.com/artsy/estella/issues/18)). It works with many ORM/ODMs, including ActiveRecord and Mongoid.

## Dependencies

* [elasticsearch-model](https://github.com/elastic/elasticsearch-rails/tree/master/elasticsearch-model)
* [ActiveSupport](https://github.com/rails/rails/tree/master/activesupport)
* [ActiveModel](https://github.com/rails/rails/tree/master/activemodel)

## Installation

```
gem 'estella'
```

Estella will try to use Elasticsearch on `localhost:9200` by default.

You can configure your global ElasticSearch client like so:

```ruby
Elasticsearch::Model.client = Elasticsearch::Client.new host: 'foo.com', log: true
```

It's also configurable on a per-model basis. Refer to the [ElasticSearch documentation](https://github.com/elastic/elasticsearch-rails/tree/master/elasticsearch-model#the-elasticsearch-client) for details.

## Indexing

Include the `Estella::Searchable` module and add a `searchable` block in your model declaring the fields to be indexed.

```ruby
class Artist < ActiveRecord::Base
  include Estella::Searchable

  searchable do
    field :name, type: :text, analysis: Estella::Analysis::FULLTEXT_ANALYSIS, factor: 1.0
    field :keywords, type: :text, analysis: ['snowball', 'shingle'], factor: 0.5
    field :bio, using: :biography, type: :text, index: false
    field :birth_date, type: :date
    field :follows, type: :integer
    field :published, type: :boolean, filter: true
    boost :follows, modifier: 'log1p', factor: 1E-3
  end
end
```

For a full list of the options available for field mappings, see the ElasticSearch [mapping documentation](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/mapping.html).

The `filter` option allows the field to be used as a filter at search time.

You can optionally provide field weightings to be applied at search time using the `factor` option. These are multipliers.

Document-level boosts can be applied with the `boost` declaration, see the [field_value_factor](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/query-dsl-function-score-query.html#function-field-value-factor) documentation for boost options.

While `filter`, `boost` and `factor` are query options, Estella allows for their static declaration in the `searchable` block for simplicity - they will be applied at query time by default when using `#estella_search`.

You can now create your index mappings with this migration:

```ruby
Artist.reload_index!
```

This uses a default index naming scheme based on your model name, which you can override simply by declaring the following in your model:

```ruby
index_name 'my_index_name'
```

Start indexing documents simply by creating or saving them:

```ruby
Artist.create(name: 'Frank Estella', keywords: ['art', 'minimalism'])
```

Estella adds `after_save` and `after_destroy` callbacks for inline indexing, override these callbacks if you'd like to do your indexing in a background process. For example:

```ruby
class Artist < ActiveRecord::Base
  include Estella::Searchable

  # disable estella inline callbacks
  skip_callback(:save, :after, :es_index)
  skip_callback(:destroy, :after, :es_delete)

  # declare your own
  after_save :delay_es_index
  after_destroy :delay_es_delete

  ...
end
```

A number of class methods are available for indexing.

```
# return true if the index exists
Artist.index_exists?

# create the index
Artist.create_index!

# delete and re-create the index without reindexing data
Artist.reload_index!

# recreate the index and reindex all data
Artist.recreate_index!

# delete the index
Artist.delete_index!

# commit any outstanding writes
Artist.refresh_index!
```

## Custom Analysis

Estella defines `standard`, `snowball`, `ngram` and `shingle` analyzers by default. These cover most search contexts, including auto-suggest. In order to enable full-text search for a field, use:

```ruby
analysis: Estella::Analysis::FULLTEXT_ANALYSIS
```

Or alternatively select your analysis by listing the analyzers you want enabled for a given field:

```ruby
field :keywords, type: :text, analysis: ['snowball', 'shingle']
```

Estella default analyzer and sharding options are defined [here](lib/estella/analysis.rb) and can be customized by passing a `settings` hash to the `searchable` block.

```ruby
my_analysis = {
  tokenizer: {
    ...
  },
  filter: {
    ...
  }
}

my_settings = {
  analysis: my_analysis,
  index: {
    number_of_shards: 1,
    number_of_replicas: 1
  }
}

searchable my_settings do
  ...
end
```

See [configuring analyzers](https://www.elastic.co/guide/en/elasticsearch/guide/current/configuring-analyzers.html) for more information.

## Searching

Perform full-text search with `estella_search`:

```ruby
Artist.estella_search(term: 'frank')
Artist.estella_search(term: 'minimalism')
```

Estella searches all analyzed text fields by default, using a [multi_match](https://www.elastic.co/guide/en/elasticsearch/guide/current/multi-match-query.html) search. The search will return an array of database records, ordered by score. If you'd like access to the raw Elasticsearch response data use the `raw` option:

```ruby
Artist.estella_search(term: 'frank', raw: true)
```

Estella supports filtering on `filter` fields and pagination:

```ruby
Artist.estella_search(term: 'frank', published: true)
Artist.estella_search(term: 'frank', size: 10, from: 5)
```

You can exclude records:

```ruby
Artist.estella_search(term: 'frank', exclude: { keywords: 'sinatra' })
```

If you'd like to customize your term query further, you can extend `Estella::Query` and override `query_definition` and `field_factors`:

```ruby
class MyQuery < Estella::Query
  def query_definition
    {
      multi_match: {
        ...
      }
    }
  end

  def field_factors
    {
      default: 5,
      ngram: 5,
      snowball: 2,
      shingle: 1,
      search: 1
    }
  end
end
```

Or manipulate the query for all cases (with or without `term`) in the initializer directly via `query` or by using built-in helpers `must` and `exclude`.

```ruby
class MyQuery < Estella::Query
  def initialize(params)
    super
    # same as query[:filter][:bool][:must] = { keywords: 'frank' }
    must(term: { keywords: 'frank' })
    # same as query[:filter][:bool][:must_not] = { keywords: 'sinatra' }
    exclude(term: { keywords: 'sinatra' })
  end
end
```

And then override class method `estella_search_query` to direct Estella to use your query object:

```ruby
class Artist < ActiveRecord::Base
  include Estella::Searchable

  searchable do
    ...
  end

  def self.estella_search_query
    MyQuery
  end
end

Artist.estella_search(term: 'frank')
```

For further search customization, see the [ElasticSearch DSL](https://github.com/elastic/elasticsearch-rails/tree/master/elasticsearch-model#the-elasticsearch-dsl).

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md).

## License

MIT License. See [LICENSE](LICENSE).
