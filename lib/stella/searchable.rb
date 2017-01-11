module Stella
  module Searchable
    # Makes your ActiveRecord model searchable via Elasticsearch
    #
    # Just include a block in your model like so:
    #
    # class Artist < ActiveRecord::Base
    #   searchable do
    #     es_field :name, type: :string, using: :my_attr, analysis: Stella::Analysis::FULLTEXT_ANALYSIS
    #     es_field :follows, type: :integer
    #     ...
    #     boost :follows, modifier: log1p, factor: 1E-3
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
    # Artist.stella_search(term: x)
    #
    extend ActiveSupport::Concern

    included do
      include Elasticsearch::Model
      include Stella::Helpers
      include Stella::Analysis

      @indexed_json = {}
      @indexed_fields = {}
      @field_boost = {}

      class << self
        attr_accessor :indexed_json, :indexed_fields, :field_boost
      end

      def self.stella_query(params = {})
        params.merge!(field_boost)
        params.merge!(indexed_fields: indexed_fields)
        Stella::Query.new(params).query
      end
    end

    def as_indexed_json(_options = {})
      schema = self.class.indexed_json
      Hash[schema.keys.zip(schema.values.map { |v| v.respond_to?(:call) ? instance_exec(&v) : send(v) })]
    end

    module ClassMethods
      def default_analysis_fields
        Stella::Analysis::DEFAULT_FIELDS
      end

      def boost(field, opts = {})
        fail ArgumentError, 'Boost field is not indexed!' unless @indexed_fields.include? field
        unless (opts.keys & [:modifier, :factor]).length == 2
          fail ArgumentError, 'Please supply a modifier and a factor for your boost!'
        end
        @field_boost = { boost: { field: field }.merge(opts) }
      end

      # index a field
      def es_field(field, opts = {})
        using = opts[:using] || field
        analysis = opts[:analysis] & default_analysis_fields.keys
        opts[:fields] ||= Hash[analysis.zip(default_analysis_fields.values_at(*analysis))] if analysis

        @indexed_json.merge!(field => using)
        @indexed_fields.merge!(field => opts)
      end

      # support for mongoid::slug
      def index_slug
        if defined? slug
          @indexed_fields.merge!(slug: { type: 'string', index: :not_analyzed })
          @indexed_json.merge!(slug: :slug)
        end
      end

      # sets up mappings and settings for index
      def searchable(settings = Stella::Analysis::DEFAULT_SETTINGS, &block)
        yield block
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
