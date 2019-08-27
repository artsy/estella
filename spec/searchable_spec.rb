require 'spec_helper'
require 'estella'
require 'active_record'

describe Estella::Searchable, type: :model do
  before do
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
  end

  describe 'searchable model', elasticsearch: true do
    before do
      class SearchableModel < ActiveRecord::Base
        include Estella::Searchable

        def self.slug
          # mongoid::slug support
          'foo'
        end

        searchable do
          field :title, type: :text, analysis: Estella::Analysis::FULLTEXT_ANALYSIS, factor: 1.0
          field :keywords, type: :text, analysis: %i[default snowball], factor: 0.5
          field :follows_count, type: :integer
          field :published, type: :boolean, filter: true

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
      @fab = SearchableModel.create(title: 'david faber', keywords: ['fab'])
      SearchableModel.refresh_index!
    end
    it 'returns relevant results' do
      expect(SearchableModel.all.size).to eq(3)
      expect(SearchableModel.estella_search(term: 'jeremy')).to eq([@jez])
      expect(SearchableModel.estella_search(term: 'theresa')).to eq([@tez])
    end
    it 'uses ngram analysis by default' do
      expect(SearchableModel.estella_search(term: 'jer')).to eq([@jez])
      expect(SearchableModel.estella_search(term: 'there')).to eq([@tez])
    end
    it 'searches all text fields by default' do
      expect(SearchableModel.estella_search(term: 'jez')).to eq([@jez])
    end
    it 'can exclude an instance' do
      expect(SearchableModel.estella_search(term: 'jez tez fab', exclude: { keywords: 'jez' })).to eq([@fab, @tez])
    end
    it 'boosts on follows_count' do
      popular_jeremy = SearchableModel.create(title: 'jeremy corban', follows_count: 20_000)
      SearchableModel.refresh_index!
      expect(SearchableModel.estella_search(term: 'jeremy')).to eq([popular_jeremy, @jez])
    end
    it 'uses factor option to weight fields' do
      @dude = SearchableModel.create(keywords: ['dude'])
      @dude2 = SearchableModel.create(title: 'dude')
      SearchableModel.refresh_index!
      expect(SearchableModel.estella_search(term: 'dude')).to eq([@dude2, @dude])
    end
    it 'returns raw response when raw option is set' do
      expect(SearchableModel.estella_search(term: 'jeremy', raw: true).hits.hits.first['_id']).to eq(@jez.id.to_s)
    end
    it 'indexes slug field by default' do
      SearchableModel.create(title: 'liapunov', slug: 'liapunov')
      SearchableModel.refresh_index!
      expect(SearchableModel.mappings.to_hash[:searchable_model][:properties].key?(:slug)).to eq true
    end
    it 'supports boolean filters' do
      liapunov = SearchableModel.create(title: 'liapunov', published: true)
      SearchableModel.create(title: 'liapunov unpublished')
      SearchableModel.refresh_index!
      expect(SearchableModel.estella_search(published: true)).to eq [liapunov]
    end
    it 'does not override field method on class' do
      expect(SearchableModel.methods.include?(:field)).to eq(false)
    end
    it 'removes a document from the index after deletion' do
      @jez.destroy
      expect(SearchableModel.estella_search(term: 'jeremy')).to eq([])
      expect(SearchableModel.estella_search(term: 'theresa')).to eq([@tez])
    end
    context 'with a deleted index' do
      before do
        SearchableModel.delete_index!
      end
      it 'recreates an index' do
        expect { SearchableModel.estella_search(term: 'theresa') }.to raise_error Elasticsearch::Transport::Transport::Errors::NotFound
        SearchableModel.recreate_index!
        expect(SearchableModel.estella_search(term: 'theresa')).to eq([@tez])
      end
      it 'indexes a bulk set of documents' do
        SearchableModel.bulk_index([@fab.id, @tez.id])
        SearchableModel.refresh_index!
        expect(SearchableModel.estella_search(term: 'jeremy')).to eq([]) # not indexes
        expect(SearchableModel.estella_search(term: 'theresa')).to eq([@tez])
        expect(SearchableModel.estella_search(term: 'david')).to eq([@fab])
      end
    end
    context 'with query customization' do
      before do
        class CustomQuery < Estella::Query
          def initialize(params)
            super
            exclude term: { keywords: 'jez' }
          end
        end

        allow(SearchableModel).to receive(:estella_search_query).and_return(CustomQuery)
      end

      it 'uses the custom query' do
        expect(SearchableModel.estella_search(term: 'jez tez fab')).to eq([@fab, @tez])
      end
    end
  end

  describe 'configuration errors' do
    it 'raises error when boost field is invalid' do
      expect do
        class BadSearchableModel < ActiveRecord::Base
          include Estella::Searchable
          searchable { boost :follows_count }
        end
      end.to raise_error(ArgumentError, 'Boost field is not indexed!')
    end
    it 'raises error when boost params are not set' do
      expect do
        class BadSearchableModel < ActiveRecord::Base
          include Estella::Searchable
          searchable do
            field :follows_count, type: 'integer'
            boost :follows_count
          end
        end
      end.to raise_error(ArgumentError, 'Please supply a modifier and a factor for your boost!')
    end
  end
end
