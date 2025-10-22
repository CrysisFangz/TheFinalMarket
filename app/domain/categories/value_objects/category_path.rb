# frozen_string_literal: true

module Categories
  module ValueObjects
    # Immutable value object representing a materialized path for hierarchical category traversal
    class CategoryPath
      # Path separator for materialized paths
      SEPARATOR = '/'
      # Maximum depth for category hierarchy
      MAX_DEPTH = 10

      # @param path_string [String] the materialized path string
      # @raise [ArgumentError] if path is invalid
      def initialize(path_string = nil)
        @path_string = path_string || SEPARATOR
        validate_path
      end

      # @return [String] the path string
      def to_s
        @path_string
      end

      # @return [Array<String>] array of path segments
      def segments
        @path_string.split(SEPARATOR).reject(&:empty?)
      end

      # @return [Integer] the depth of the category in the hierarchy
      def depth
        segments.length
      end

      # @return [Boolean] true if this is a root category
      def root?
        depth.zero?
      end

      # @return [CategoryPath] parent path or nil if root
      def parent_path
        return nil if root?

        parent_segments = segments[0..-2]
        self.class.new(SEPARATOR + parent_segments.join(SEPARATOR))
      end

      # @param child_name [String] name to append as child
      # @return [CategoryPath] new path with child appended
      def child_path(child_name)
        raise ArgumentError, 'Child name cannot be nil or empty' if child_name.nil? || child_name.strip.empty?

        new_path = @path_string + child_name.strip + SEPARATOR
        self.class.new(new_path)
      end

      # @param other [CategoryPath] path to compare
      # @return [Boolean] true if paths are equal
      def ==(other)
        return false unless other.is_a?(CategoryPath)
        @path_string == other.to_s
      end

      # @return [Boolean] true if other path is an ancestor
      def ancestor_of?(other)
        return false unless other.is_a?(CategoryPath)
        return false if depth >= other.depth

        other.to_s.start_with?(@path_string)
      end

      # @return [Boolean] true if other path is a descendant
      def descendant_of?(other)
        return false unless other.is_a?(CategoryPath)
        return false if depth <= other.depth

        @path_string.start_with?(other.to_s)
      end

      # @return [String] string representation for serialization
      def for_storage
        @path_string
      end

      private

      # Validates the materialized path
      # @raise [ArgumentError] if path is invalid
      def validate_path
        unless @path_string.start_with?(SEPARATOR)
          raise ArgumentError, 'Path must start with separator'
        end

        unless @path_string.end_with?(SEPARATOR)
          raise ArgumentError, 'Path must end with separator'
        end

        unless depth <= MAX_DEPTH
          raise ArgumentError, "Path depth cannot exceed #{MAX_DEPTH}"
        end

        # Check for consecutive separators (empty segments)
        unless @path_string.scan(/\/+/).all? { |match| match.length == 1 }
          raise ArgumentError, 'Path cannot contain consecutive separators'
        end
      end
    end
  end
end