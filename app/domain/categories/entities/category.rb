# frozen_string_literal: true

require 'securerandom'

module Categories
  module Entities
    # Domain entity representing a Category in the business domain
    class Category
      # Maximum depth for category hierarchy
      MAX_DEPTH = 10

      # @param name [ValueObjects::CategoryName] category name
      # @param description [String] category description
      # @param path [ValueObjects::CategoryPath] materialized path
      # @param status [ValueObjects::CategoryStatus] category status
      # @param id [String] unique identifier (optional)
      def initialize(name:, description: nil, path: nil, status: nil, id: nil)
        @id = id || generate_id
        @name = name
        @description = description
        @path = path || ValueObjects::CategoryPath.new
        @status = status || ValueObjects::CategoryStatus.new(:pending)
        @created_at = Time.current
        @updated_at = Time.current

        validate_invariants
      end

      # @return [String] unique identifier
      attr_reader :id

      # @return [ValueObjects::CategoryName] category name
      attr_reader :name

      # @return [String] category description
      attr_reader :description

      # @return [ValueObjects::CategoryPath] materialized path
      attr_reader :path

      # @return [ValueObjects::CategoryStatus] category status
      attr_reader :status

      # @return [Time] creation timestamp
      attr_reader :created_at

      # @return [Time] last update timestamp
      attr_reader :updated_at

      # Updates category properties
      # @param name [ValueObjects::CategoryName] new name (optional)
      # @param description [String] new description (optional)
      # @param status [ValueObjects::CategoryStatus] new status (optional)
      # @return [Category] new category instance with updated properties
      def update(name: nil, description: nil, status: nil)
        new_name = name || @name
        new_description = description.nil? ? @description : description
        new_status = status || @status

        self.class.new(
          name: new_name,
          description: new_description,
          path: @path,
          status: new_status,
          id: @id
        )
      end

      # Moves category to a new parent path
      # @param new_parent_path [ValueObjects::CategoryPath] new parent path
      # @return [Category] new category instance with updated path
      def move_to(new_parent_path)
        raise ArgumentError, 'Cannot move category to itself' if new_parent_path == @path

        new_path = if new_parent_path.root?
                     ValueObjects::CategoryPath.new("/#{@name}/")
                   else
                     new_parent_path.child_path(@name.to_s)
                   end

        self.class.new(
          name: @name,
          description: @description,
          path: new_path,
          status: @status,
          id: @id
        )
      end

      # @return [Boolean] true if category is root
      def root?
        @path.root?
      end

      # @return [Boolean] true if category is a leaf (no children)
      def leaf?
        true # In materialized path, all categories are considered leaves
      end

      # @return [Integer] depth in hierarchy
      def depth
        @path.depth
      end

      # @return [Boolean] true if category can have children
      def can_have_children?
        depth < MAX_DEPTH
      end

      # @return [Boolean] true if category is active
      def active?
        @status.active?
      end

      # @return [Boolean] true if category is usable
      def usable?
        @status.usable?
      end

      # @return [Boolean] true if category can be displayed
      def displayable?
        @status.displayable?
      end

      # @param other [Category] category to compare
      # @return [Boolean] true if categories are equal
      def ==(other)
        return false unless other.is_a?(Category)
        @id == other.id
      end

      # @return [Integer] hash code for the category
      def hash
        @id.hash
      end

      # @return [Hash] category data for serialization
      def to_h
        {
          id: @id,
          name: @name.to_s,
          description: @description,
          path: @path.to_s,
          status: @status.to_s,
          depth: depth,
          root: root?,
          active: active?,
          created_at: @created_at,
          updated_at: @updated_at
        }
      end

      private

      # Generates a unique identifier for the category
      # @return [String] unique identifier
      def generate_id
        SecureRandom.uuid
      end

      # Validates business invariants
      # @raise [ArgumentError] if invariants are violated
      def validate_invariants
        unless depth <= MAX_DEPTH
          raise ArgumentError, "Category depth cannot exceed #{MAX_DEPTH}"
        end

        if @description && @description.length > 500
          raise ArgumentError, 'Category description cannot exceed 500 characters'
        end

        # Root categories must have active or pending status
        unless root? || @status.active? || @status.pending?
          raise ArgumentError, 'Non-root categories must be active or pending'
        end
      end
    end
  end
end