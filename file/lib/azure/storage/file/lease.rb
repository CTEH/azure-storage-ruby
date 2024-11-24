require "azure/storage/file/serialization"

module Azure::Storage::File
  include Azure::Storage::Common::Service

  class Lease
    def initialize
      @properties = {}
      @metadata = {}
      yield self if block_given?
    end

    attr_accessor :time
    attr_accessor :lease_id
    attr_accessor :properties
    attr_accessor :metadata
  end
end