module Stella
  class Query
    # Constructs a search query for ES
    attr_accessor :query
    attr_reader :params

    def initialize(params)
      @params = params
      @query = {
        _source: false,
        query: {},
        filter: {
          bool: { must: [], must_not: [] }
        },
        aggregations: {}
      }
      add_query
      add_filters
      add_pagination
      add_aggregations if params[:aggregations]
      add_sort
    end

    # override if needed
    def add_aggregations; end

    # override if needed
    def add_sort; end

    def must(filter)
      query[:filter][:bool][:must] << filter
    end

    def exclude(filter)
      query[:filter][:bool][:must_not] << filter
    end

    def add_pagination
      query[:size] = params[:size] if params[:size]
      query[:from] = params[:from] if params[:from]
    end

    def add_query
      if params[:term] && params[:indexed_fields]
        add_term_query
      else
        query[:query] = { match_all: {} }
      end
    end

    # fulltext search across all string fields
    def add_term_query
      query[:query] = {
        function_score: {
          query: query_definition
        }
      }

      add_field_boost
    end

    def query_definition
      {
        multi_match: {
          type: 'most_fields',
          fields: term_search_fields,
          query: params[:term]
        }
      }
    end

    def add_field_boost
      if params[:boost]
        query[:query][:function_score][:field_value_factor] = {
          field: params[:boost][:field],
          modifier: params[:boost][:modifier],
          factor: params[:boost][:factor]
        }

        if params[:boost][:max]
          query[:query][:function_score][:max_boost] = params[:boost][:max]
        end
      end
    end

    def field_factors
      Stella::Analysis::DEFAULT_FIELD_FACTORS
    end

    # search all analysed string fields by default
    # boost them by factor if provided
    def term_search_fields
      params[:indexed_fields]
        .select { |_, opts| opts[:type].to_s == 'string' }
        .reject { |_, opts| opts[:analysis].nil? }
        .map do |field, opts|
          opts[:analysis].map do |analyzer|
            factor = field_factors[analyzer] * opts.fetch(:factor, 1.0)
            "#{field}.#{analyzer}^#{factor}"
          end
        end
        .flatten
    end

    def add_filters
      if params[:indexed_fields]
        params[:indexed_fields].each do |field, opts|
          must term: { field => params[field] } if opts[:filter] && params[field]
        end
      end
    end

    def bool_filter(field, param)
      if param
        { term: { field => true } }
      elsif !param.nil?
        { term: { field => false } }
      end
    end

    def add_bool_filter(field, param)
      must bool_filter(field, param) if bool_filter(field, param)
    end
  end
end
