require 'spec_helper'
require 'stella'
require 'elasticsearch/model'
require 'active_record'

describe Stella::Searchable do

  ActiveRecord::Base.establish_connection( adapter: 'sqlite3', database: ":memory:" )
  ActiveRecord::Schema.define(version: 1) { create_table(:searchable_models) { |t| t.string :title } }

  class SearchableModel < ActiveRecord::Base
    # include ActiveModel::Model
    # extend ActiveModel::Callbacks
    include Elasticsearch::Model

    attr_accessor :id, :title
    define_model_callbacks :save, :destroy
  end

  describe 'test es', elasticsearch: true do
    it 'test' do
      SearchableModel.new(title: 'foo fighters').__elasticsearch__.index_document
      SearchableModel.new(title: 'bar fighters').__elasticsearch__.index_document
      SearchableModel.new(title: 'quux fighters').__elasticsearch__.index_document
      SearchableModel.import
      expect(SearchableModel.search('blah')).to eq "blah"
    end
  end
end
