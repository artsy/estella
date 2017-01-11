# stella

Makes your Ruby ActiveRecord models searchable with Elasticsearch. Provides fine-grained control of fields, analysers, weightings and boosts. Built on top of [elasticsearch-model](https://github.com/elastic/elasticsearch-rails/tree/master/elasticsearch-model).

Just include a `searchable` block in your ActiveRecord model declaring the fields to be indexed like so:

```ruby
class Artist < ActiveRecord
    searchable do
      es_field :name, type: :string, using: :my_attr, analysis: Stella::Analysis::FULLTEXT_ANALYSIS, factor: 1.0
      es_field :keywords, type: :string, analysis: ['snowball', 'shingle'], factor: 0.5
      es_field :bio, type: :string, index: :not_analyzed
      es_field :birth_date, type: :date

      boost :title, modifier: log1p, factor: 1E-3
    end
    ...
end
```

Optionally provide weightings using the `factor` option or document-level boosts using the `boost` declaration.

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
```
Stella searches all analysed text fields by default. The search will return an array of database records in score order. If you'd like access to the raw Elasticsearch response data use:

```ruby
Article.stella_search(term: 'frank', raw: true)
```
