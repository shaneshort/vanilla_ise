# frozen_string_literal: true

module VanillaIse
  # The base object class for all other objects.
  class Object < OpenStruct
    # create a new object
    # @param [Hash] attributes The attributes to initialize the object with.
    # @return [VanillaIse::Object]
    def initialize(attributes)
      super to_ostruct(attributes)
    end

    # This method is used to convert a Hash or an Array to an OpenStruct (or array of them).
    # @param [Hash, Array] obj The object to convert.
    # @return [OpenStruct, Array] The converted object.
    def to_ostruct(obj)
      if obj.is_a?(Hash)
        OpenStruct.new(obj.transform_values { |val| to_ostruct(val) })
      elsif obj.is_a?(Array)
        obj.map { |o| to_ostruct(o) }
      else
        # Assumed to be a primitive value
        obj
      end
    end

    # This method is used to determine if the object has been persisted.
    # @return [Boolean] Whether the object has been persisted.
    def persisted?
      !!id
    end

    # This performs mass assignment on the object.
    # @param [Hash] attributes The attributes to assign to the object.
    # @return [Hash]
    def attributes=(attributes)
      attributes.each { |k, v| send("#{k}=", v) }
    end
  end
end
