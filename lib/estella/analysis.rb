# frozen_string_literal: true

module Estella
  module Analysis
    # Default Elasticsearch analysers
    extend ActiveSupport::Concern

    FRONT_NGRAM_FILTER =
      { type: 'edge_ngram', min_gram: 2, max_gram: 15, side: 'front' }

    DEFAULT_ANALYZER =
      { type: 'custom', tokenizer: 'standard_tokenizer', filter: %w[lowercase asciifolding] }

    SNOWBALL_ANALYZER =
      { type: 'custom', tokenizer: 'standard_tokenizer', filter: %w[lowercase asciifolding snowball] }

    SHINGLE_ANALYZER =
      { type: 'custom', tokenizer: 'standard_tokenizer', filter: %w[shingle lowercase asciifolding] }

    NGRAM_ANALYZER =
      { type: 'custom', tokenizer: 'standard_tokenizer', filter: %w[lowercase asciifolding front_ngram_filter] }

    DEFAULT_ANALYSIS = {
      tokenizer: {
        standard_tokenizer: { type: 'standard' }
      },
      filter: {
        front_ngram_filter: FRONT_NGRAM_FILTER
      },
      analyzer: {
        default_analyzer: DEFAULT_ANALYZER,
        snowball_analyzer: SNOWBALL_ANALYZER,
        shingle_analyzer: SHINGLE_ANALYZER,
        ngram_analyzer: NGRAM_ANALYZER,
        search_analyzer: DEFAULT_ANALYZER
      }
    }

    DEFAULT_FIELDS = {
      default: { type: 'text', analyzer: 'default_analyzer' },
      snowball: { type: 'text', analyzer: 'snowball_analyzer' },
      shingle: { type: 'text', analyzer: 'shingle_analyzer' },
      ngram: { type: 'text', analyzer: 'ngram_analyzer', search_analyzer: 'search_analyzer' }
    }

    DEFAULT_FIELD_FACTORS = {
      default: 10,
      ngram: 10,
      snowball: 3,
      shingle: 2,
      search: 2
    }

    FULLTEXT_ANALYSIS = DEFAULT_FIELDS.keys

    DEFAULT_SETTINGS = if defined? Rails && Rails.env == 'test'
                         # Ensure no sharding in test env in order to enforce deterministic scores.
                         { analysis: DEFAULT_ANALYSIS, index: { number_of_shards: 1, number_of_replicas: 1 } }
                       else
                         { analysis: DEFAULT_ANALYSIS }
                       end
  end
end
