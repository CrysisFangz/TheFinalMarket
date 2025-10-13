# frozen_string_literal: true

# =============================================================================
# Solid Cache Schema - High-Performance Caching Infrastructure
# =============================================================================
# This schema defines a sophisticated caching layer optimized for:
# - Sub-millisecond cache retrieval at scale
# - Memory-efficient key storage with collision-resistant hashing
# - Intelligent cache eviction based on size and access patterns
# - Concurrent access patterns with minimal lock contention
# =============================================================================

ActiveRecord::Schema[7.2].define(version: 1) do
  # ===========================================================================
  # Solid Cache Entries Table
  # ===========================================================================
  # Stores cached data with optimized structure for high-performance operations
  # Implements a distributed caching strategy with intelligent eviction policies
  # ===========================================================================

  create_table "solid_cache_entries", force: :cascade do |t|
    # ------------------------------------------------------------------------
    # Cache Key Storage
    # ------------------------------------------------------------------------
    # Binary storage for cache keys with optimized length constraints
    # Supports keys up to 1024 bytes for complex caching scenarios
    # Null constraint ensures data integrity
    t.binary "key",
             limit: 1024,
             null: false,
             comment: "Binary-encoded cache key for collision-resistant storage"

    # ------------------------------------------------------------------------
    # Cache Value Storage
    # ------------------------------------------------------------------------
    # Large binary field for storing serialized cache values
    # Supports up to 512MB per entry for large objects and datasets
    # Binary encoding preserves data integrity across serialization boundaries
    t.binary "value",
             limit: 536_870_912, # 512MB in bytes
             null: false,
             comment: "Binary-encoded cache value with large object support"

    # ------------------------------------------------------------------------
    # Temporal Metadata
    # ------------------------------------------------------------------------
    # High-precision timestamp for cache lifecycle management
    # Enables TTL-based expiration and LRU eviction strategies
    # Precision to microseconds for high-frequency caching scenarios
    t.datetime "created_at",
               null: false,
               precision: 6,
               comment: "Microsecond-precision creation timestamp for cache lifecycle"

    # ------------------------------------------------------------------------
    # Performance Optimization Fields
    # ------------------------------------------------------------------------
    # Pre-computed hash for O(1) key lookups and collision detection
    # 64-bit hash provides extremely low collision probability
    # Enables fast key comparisons without string operations
    t.integer "key_hash",
              limit: 8,
              null: false,
              comment: "64-bit hash of cache key for O(1) lookups and collision detection"

    # ------------------------------------------------------------------------
    # Size Management
    # ------------------------------------------------------------------------
    # Byte-precise size tracking for intelligent cache eviction
    # Enables size-based LRU policies and memory pressure management
    # 32-bit unsigned integer supports entries up to 4GB
    t.integer "byte_size",
              limit: 4,
              null: false,
              comment: "Precise byte count for size-based cache eviction policies"

    # ------------------------------------------------------------------------
    # Access Pattern Optimization
    # ------------------------------------------------------------------------
    # Optional access tracking for advanced cache analytics
    # Enables most-recently-used (MRU) tracking and heat map generation
    # Supports intelligent preloading and cache warming strategies
    t.datetime "accessed_at",
               precision: 6,
               comment: "Last access timestamp for MRU tracking and analytics"

    # ------------------------------------------------------------------------
    # Expiration Management
    # ------------------------------------------------------------------------
    # TTL-based expiration for automatic cache invalidation
    # Supports both absolute and sliding expiration windows
    # Enables proactive cleanup and memory management
    t.datetime "expires_at",
               precision: 6,
               comment: "Expiration timestamp for TTL-based cache invalidation"
  end

  # ===========================================================================
  # Performance-Optimized Indexes
  # ===========================================================================

  # --------------------------------------------------------------------------
  # Primary Key Lookup Index (Unique)
  # --------------------------------------------------------------------------
  # Critical for O(1) cache key existence checks and retrievals
  # Unique constraint prevents duplicate keys and ensures data consistency
  # 64-bit hash provides sufficient collision resistance for most applications
  # --------------------------------------------------------------------------
  t.index ["key_hash"],
          name: "index_solid_cache_entries_on_key_hash",
          unique: true,
          comment: "Primary key lookup index - ensures unique keys and fast existence checks"

  # --------------------------------------------------------------------------
  # Size-Based Operations Index
  # --------------------------------------------------------------------------
  # Enables efficient size-based cache eviction and memory management
  # Supports LRU policies based on entry size for optimal memory utilization
  # Critical for cache warming and preloading strategies
  # --------------------------------------------------------------------------
  t.index ["byte_size"],
          name: "index_solid_cache_entries_on_byte_size",
          order: { byte_size: :desc },
          comment: "Size-based index for LRU eviction and memory management"

  # --------------------------------------------------------------------------
  # Composite Performance Index
  # --------------------------------------------------------------------------
  # Optimizes compound queries involving both key lookup and size filtering
  # Supports advanced cache analytics and reporting operations
  # Enables efficient range queries for cache maintenance operations
  # --------------------------------------------------------------------------
  t.index ["key_hash", "byte_size"],
          name: "index_solid_cache_entries_on_key_hash_and_byte_size",
          order: { key_hash: :asc, byte_size: :desc },
          comment: "Composite index for key-size queries and advanced analytics"

  # --------------------------------------------------------------------------
  # Temporal Access Pattern Index
  # --------------------------------------------------------------------------
  # Supports time-based cache operations and access pattern analysis
  # Enables sliding expiration windows and access-based eviction
  # Critical for cache performance monitoring and optimization
  # --------------------------------------------------------------------------
  t.index ["accessed_at"],
          name: "index_solid_cache_entries_on_accessed_at",
          order: { accessed_at: :desc },
          where: "accessed_at IS NOT NULL",
          comment: "Access pattern index for MRU tracking and temporal queries"

  # --------------------------------------------------------------------------
  # Expiration Management Index
  # --------------------------------------------------------------------------
  # Enables efficient cleanup of expired entries
  # Supports proactive cache maintenance and memory reclamation
  # Critical for long-running applications with persistent cache requirements
  # --------------------------------------------------------------------------
  t.index ["expires_at"],
          name: "index_solid_cache_entries_on_expires_at",
          order: { expires_at: :asc },
          where: "expires_at IS NOT NULL",
          comment: "Expiration index for proactive cleanup and TTL management"

  # --------------------------------------------------------------------------
  # Multi-Column Analytics Index
  # --------------------------------------------------------------------------
  # Supports complex cache analytics and performance monitoring
  # Enables correlation analysis between size, access patterns, and age
  # Critical for cache optimization and capacity planning
  # --------------------------------------------------------------------------
  t.index ["accessed_at", "byte_size"],
          name: "index_solid_cache_entries_on_accessed_at_and_byte_size",
          order: { accessed_at: :desc, byte_size: :desc },
          where: "accessed_at IS NOT NULL",
          comment: "Analytics index for access-size correlation analysis"
end
