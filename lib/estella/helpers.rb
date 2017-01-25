module Estella
  module Helpers
    extend ActiveSupport::Concern

    @@types = []

    included do
      index_name search_index_name

      after_save :es_index
      after_destroy :es_delete

      attr_accessor :es_indexing

      @@types << self
    end

    # track dependent classes for spec support
    def self.types
      @@types
    end

    def es_index
      self.es_indexing = true
      __elasticsearch__.index_document
    ensure
      self.es_indexing = nil
    end

    def es_delete
      es_delete_document id
    end

    def es_transform
      { index: { _id: id.to_s, data: as_indexed_json } }
    end

    module ClassMethods
      ## Searching

      def estella_raw_search(params = {})
        __elasticsearch__.search(estella_query(params))
      end

      # @return an array of database records mapped using an adapter
      def estella_search(params = {})
        rsp = estella_raw_search(params)
        params[:raw] ? rsp.response : rsp.records.to_a
      end

      ## Indexing

      # default index naming scheme is pluralized model_name
      def search_index_name
        model_name.route_key
      end

      def batch_to_bulk(batch_of_ids)
        find(batch_of_ids).map(&:es_transform)
      end

      def bulk_index(batch_of_ids)
        __elasticsearch__.client.bulk index: index_name, type: model_name.element, body: batch_to_bulk(batch_of_ids)
      end

      def index_exists?
        __elasticsearch__.client.indices.exists index: index_name
      end

      def reload_index!
        __elasticsearch__.client.indices.delete index: index_name if index_exists?
        __elasticsearch__.client.indices.create index: index_name, body: { settings: settings.to_hash, mappings: mappings.to_hash }
      end

      def recreate_index!
        reload_index!
        import
        refresh_index!
      end

      def refresh_index!
        __elasticsearch__.refresh_index!
      end

      def set_index_alias!(name)
        __elasticsearch__.client.indices.put_alias index: index_name, name: name
      end

      def es_delete_document(id)
        __elasticsearch__.client.delete type: document_type, id: id, index: index_name
      end
    end
  end
end
