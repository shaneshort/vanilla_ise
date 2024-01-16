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

    # This method is used to recursively convert the object to a Hash,
    # handling nested OpenStructs, which will prevent badly serialised
    # data being sent to the API.
    # Note: Because this method is recursive, super is used to call an
    # unmodified to_h method (from OpenStruct).
    # @return [Hash] The object as a Hash.
    def to_h
      super.transform_values do |value|
        value.is_a?(OpenStruct) ? value.to_h : value
      end
    end
  end
end
