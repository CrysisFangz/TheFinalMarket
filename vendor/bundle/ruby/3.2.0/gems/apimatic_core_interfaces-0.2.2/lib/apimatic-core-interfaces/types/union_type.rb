module CoreLibrary
  # Represents a union type that can validate, serialize and deserialize values based on a set of allowed types.
  class UnionType
    # NATIVE_TYPES represents the list of native types in Ruby.
    # These types are commonly used and built-in to the Ruby language.
    # The constant contains the following types:
    # - Integer: Represents whole numbers without a decimal point.
    # - String: Represents a sequence of characters.
    # - Float: Represents floating-point numbers with a decimal point.
    # - TrueClass: Represents the boolean value `true`.
    # - FalseClass: Represents the boolean value `false`.
    # This constant is used within the UnionType class to define the allowed native types.
    NATIVE_TYPES = [Integer, String, Float, TrueClass, FalseClass].freeze

    attr_accessor :is_valid, :error_messages, :union_type_context, :union_types

    # Initializes a new instance of UnionType.
    # @param union_types [Array<Class>] An array of allowed types for the union.
    # @param union_type_context [Object] The context of the union type.
    def initialize(union_types, union_type_context)
      @union_types = union_types
      @union_type_context = union_type_context
      @is_valid = false
      @error_messages = Set.new
    end

    # Validates a value against the union type.
    # This method should be implemented by subclasses.
    # @param value [Object] The value to validate.
    # @raise [NotImplementedError] If the method is not implemented in a subclass.
    def validate(value)
      raise NotImplementedError, 'This method needs
          to be implemented in a child class.'
    end

    # Serializes a given value.
    # @param value [Object] The value to be serialized.
    # @raise [NotImplementedError] If the method is not implemented in the child class.
    # @return [String] The serialized representation of the value.
    def serialize(value)
      raise NotImplementedError, 'This method needs
          to be implemented in a child class.'
    end

    # Deserializes a value based on the union type.
    # This method should be implemented by subclasses.
    # @param value [Object] The value to deserialize.
    # @param should_symbolize [Boolean] Indicates whether the deserialized value should be symbolized.
    # @raise [NotImplementedError] If the method is not implemented in a subclass.
    def deserialize(value, should_symbolize: false)
      raise NotImplementedError, 'This method needs
          to be implemented in a child class.'
    end
  end
end
