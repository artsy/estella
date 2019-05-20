module Estella
  module Searchable
    # Makes your ActiveRecord model searchable via Elasticsearch
    #
    # Just include a block in your model like so:
    #
    # class Artist < ActiveRecord::Base
    #   searchable do
    #     field :name, type: :string, using: :my_attr, analysis: Estella::Analysis::FULLTEXT_ANALYSIS
    #     field :follows, type: :integer
    #     ...
    #     boost :follows, modifier: 'log1p', factor: 1E-3
    #   end
    # end
    #
    # Document boosts are optional.
    # You can now create your index with the following migration:
    #
    # Artist.reload_index!
    # Artist.import
    #
    # And perform full-text search using:
    #
    # Artist.estella_search(term: x)
    #
    extend ActiveSupport::Concern

    included do
      include Elasticsearch::Model
      include Estella::Helpers
      include Estella::Analysis

      @indexed_json = {}
      @indexed_fields = {}
      @field_boost = {}

      class << self
        attr_accessor :indexed_json, :indexed_fields, :field_boost
      end

      def self.estella_query(params = {})
        params.merge!(field_boost)
        params.merge!(indexed_fields: indexed_fields)
        estella_search_query.new(params).query
      end

      def self.estella_search_query
        Estella::Query
      end
    end

    def as_indexed_json(_options = {})
      schema = self.class.indexed_json
      Hash[schema.keys.zip(schema.values.map { |v| v.respond_to?(:call) ? instance_exec(&v) : send(v) })]
    end

    module ClassMethods
      # support for mongoid::slug
      # indexes slug attribute by default
      def index_slug
        if defined? slug
          indexed_fields.merge!(slug: { type: :text, index: :not_analyzed })
          indexed_json.merge!(slug: :slug)
        end
      end

      def default_analysis_fields
        Estella::Analysis::DEFAULT_FIELDS
      end

      # sets up mappings and settings for index
      def searchable(settings = Estella::Analysis::DEFAULT_SETTINGS, &block)
        Estella::Parser.new(self).instance_eval(&block)
        index_slug
        indexed_fields = @indexed_fields

        settings(settings) do
          mapping do
            indexed_fields.each do |name, opts|
              indexes name, opts.except(:analysis, :using, :factor, :filter)
            end
          end
        end
      end
    end
  end
end
