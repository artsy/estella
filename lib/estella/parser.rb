# frozen_string_literal: true

module Estella
  class Parser
    def initialize(model)
      @model = model
    end

    # document level boost
    # @see https://www.elastic.co/guide/en/elasticsearch/guide/current/boosting-by-popularity.html
    def boost(name, opts = {})
      raise ArgumentError, 'Boost field is not indexed!' unless @model.indexed_fields.include? name
      raise ArgumentError, 'Please supply a modifier and a factor for your boost!' unless (opts.keys & %i[modifier
                                                                                                          factor]).length == 2

      @model.field_boost = { boost: { field: name }.merge(opts) }
    end

    # index a field
    def field(name, opts = {})
      using = opts[:using] || name
      analysis = opts[:analysis] & @model.default_analysis_fields.keys
      opts[:fields] ||= Hash[analysis.zip(@model.default_analysis_fields.values_at(*analysis))] if analysis
      include_raw = opts.delete(:include_raw)
      opts[:fields][:raw] = { type: 'keyword' } if include_raw
      @model.indexed_json.merge!(name => using)
      @model.indexed_fields.merge!(name => opts)
    end
  end
end
