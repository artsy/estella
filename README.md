# stella

Builds on [elasticsearch-model](https://github.com/elastic/elasticsearch-rails/tree/master/elasticsearch-model) to make your Ruby objects searchable with Elasticsearch. Provides fine-grained control of fields, analysis, filters, weightings and boosts.

Just include the `Stella::Searchable` module and add a `searchable` block in your ActiveRecord model declaring the fields to be indexed like so:

```ruby
class Artist < ActiveRecord
    include Stella::Searchable

    searchable do
      es_field :name, type: :string, using: :my_attr, analysis: Stella::Analysis::FULLTEXT_ANALYSIS, factor: 1.0
      es_field :keywords, type: :string, analysis: ['snowball', 'shingle'], factor: 0.5
      es_field :bio, type: :string, index: :not_analyzed
      es_field :birth_date, type: :date
      es_field :follows, type: :integer
      es_field :published, type: :boolean, filter: true
      boost :follows, modifier: 'log1p', factor: 1E-3
    end
    ...
end
```

For a full understanding of the options available for field mappings, see the [Elastic mapping documentation](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/mapping.html). 

Stella defines `standard`, `snowball`, `ngram` and `shingle` analysers by default. These cover most search contexts, including auto-suggest. In order to enable full-text search for a field, use:

```
analysis: Stella::Analysis::FULLTEXT_ANALYSIS
```

Or alternatively customize your analysis by listing the analysers you want enabled for a given field.

The `filter` declaration allows for the field to be used as a boolean filter at search time.

You can optionally provide field weightings using the `factor` option or document-level boosts using the `boost` declaration. While these are query options, Stella allows for their static declaration in the `searchable` block for simplicity - they will be applied at query time by default.

You can now create your index with the following migration:

```ruby
Article.reload_index!
Article.create(name: 'Frank Stella', keywords: ['art', 'minimalism'])
```

Stella adds `after_save` and `after_destroy` callbacks for inline indexing, override these if you'd like to do your indexing in a background process.

Finally perform full-text search using:

```ruby
Article.stella_search(term: 'frank')
Article.stella_search(term: 'minimalism')
Article.stella_search(term: 'frank', published: true)
```

Stella searches all analysed text fields by default. The search will return an array of database records in score order. If you'd like access to the raw Elasticsearch response data use the `raw` option:

```ruby
Article.stella_search(term: 'frank', raw: true)
```

Stella works with any ActiveRecord compatible database backend (MySQL, sqlite, Postgres, Mongoid).
