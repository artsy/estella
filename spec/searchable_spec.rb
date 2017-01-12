require 'spec_helper'
require 'stella'
require 'active_record'

describe Stella::Searchable, type: :model do
  before do
    ActiveRecord::Base.establish_connection( adapter: 'sqlite3', database: ":memory:" )
  end

  describe 'searchable model', elasticsearch: true do
    before do
      class SearchableModel < ActiveRecord::Base
        include Stella::Searchable

        searchable do
          es_field :title, type: :string, analysis: Stella::Analysis::FULLTEXT_ANALYSIS, factor: 1.0
          es_field :keywords, type: :string, analysis: [:default, :snowball], factor: 0.5
          es_field :follows_count, type: :integer
          es_field :published, type: :boolean, filter: true

          boost :follows_count, modifier: 'log2p', factor: 5E-4, max: 1.0
        end
      end

      ActiveRecord::Schema.define(version: 1) do
        create_table(:searchable_models) do |t|
          t.string :title
          t.string :keywords
          t.string :slug
          t.boolean :published
          t.integer :follows_count, default: 0
        end
      end

      SearchableModel.reload_index!
      @jez = SearchableModel.create(title: 'jeremy corbyn', keywords: ['jez'])
      @tez = SearchableModel.create(title: 'theresa may', keywords: ['tez'])
      SearchableModel.refresh_index!
    end
    it 'returns relevant results' do
      expect(SearchableModel.all.size).to eq(2)
      expect(SearchableModel.stella_search(term: 'jeremy')).to eq([@jez])
      expect(SearchableModel.stella_search(term: 'theresa')).to eq([@tez])
    end
    it 'uses ngram analysis by default' do
      expect(SearchableModel.stella_search(term: 'jer')).to eq([@jez])
      expect(SearchableModel.stella_search(term: 'there')).to eq([@tez])
    end
    it 'searches all text fields by default' do
      expect(SearchableModel.stella_search(term: 'jez')).to eq([@jez])
    end
    it 'boosts on follows_count' do
      popular_jeremy = SearchableModel.create(title: 'jeremy corban', follows_count: 20000)
      SearchableModel.refresh_index!
      expect(SearchableModel.stella_search(term: 'jeremy')).to eq([popular_jeremy, @jez])
    end
    it 'uses factor option to weight fields' do
      @dude = SearchableModel.create(keywords: ['dude'])
      @dude2 = SearchableModel.create(title: 'dude')
      SearchableModel.refresh_index!
      expect(SearchableModel.stella_search(term: 'dude')).to eq([@dude2, @dude])
    end
    it 'returns raw response when raw option is set' do
      expect(SearchableModel.stella_search(term: 'jeremy', raw: true).hits.hits.first['_id']).to eq(@jez.id.to_s)
    end
    it 'indexes slug field by default' do
      SearchableModel.create(title: 'liapunov', slug: 'liapunov')
      SearchableModel.refresh_index!
      expect(SearchableModel.mappings.to_hash[:searchable_model][:properties].keys.include? :slug).to eq true
    end
    it 'supports boolean filters' do
      @liapunov = SearchableModel.create(title: 'liapunov', published: true)
      SearchableModel.create(title: 'liapunov unpublished')
      SearchableModel.refresh_index!
      expect(SearchableModel.stella_search(published: true)).to eq ([@liapunov])
    end
  end

  describe 'configuration errors' do
    it 'raises error when boost field is invalid' do
      expect do
        class BadSearchableModel  < ActiveRecord::Base
          include Stella::Searchable
          searchable { boost :follows_count }
        end
      end.to raise_error(ArgumentError, 'Boost field is not indexed!')
    end
    it 'raises error when boost params are not set' do
      expect do
        class BadSearchableModel < ActiveRecord::Base
          include Stella::Searchable
          searchable do
            es_field :follows_count, type: 'integer'
            boost :follows_count
          end
        end
      end.to raise_error(ArgumentError, 'Please supply a modifier and a factor for your boost!')
    end
  end
end
