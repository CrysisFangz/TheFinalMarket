# Enhanced Solid Cable Messages Schema
# Enterprise-grade messaging infrastructure with advanced performance optimizations
ActiveRecord::Schema[7.1].define(version: 1) do
  # Core messaging table with advanced partitioning and performance optimizations
  create_table "solid_cable_messages", force: :cascade do |t|
    # Channel identification with optimized binary storage
    # Supports up to 1024 bytes for complex channel identifiers
    t.binary "channel", 
             limit: 1024, 
             null: false,
             comment: "Channel identifier for message routing - supports complex channel structures"
    
    # Message payload with intelligent compression support
    # Massive 512MB limit supports rich media and complex data structures
    t.binary "payload", 
             limit: 536870912, 
             null: false,
             comment: "Compressed message payload - supports rich media and complex data structures"
    
    # High-precision timestamp for sub-millisecond message ordering
    t.datetime "created_at", 
               null: false, 
               default: -> { "CURRENT_TIMESTAMP" },
               comment: "Message creation timestamp with microsecond precision"
    
    # Optimized channel hashing for ultra-fast lookups
    # 8-byte integer provides excellent distribution for sharding
    t.integer "channel_hash", 
              limit: 8, 
              null: false,
              comment: "Pre-computed hash for channel-based partitioning and fast lookups"
    
    # Message metadata for advanced analytics and monitoring
    t.integer "payload_size",
              null: false,
              comment: "Original payload size in bytes for analytics and optimization"
    
    t.integer "compression_ratio",
              null: true,
              comment: "Compression ratio (0-100) for performance monitoring"
    
    # Message classification for intelligent routing and processing
    t.string "message_type", 
             limit: 50,
             null: true,
             comment: "Message classification for intelligent routing (chat, system, media, etc.)"
    
    t.string "priority",
             limit: 20,
             null: false,
             default: "normal",
             comment: "Message priority level (low, normal, high, critical)"
    
    # Advanced delivery tracking for reliability
    t.integer "delivery_attempts",
              null: false,
              default: 0,
              comment: "Number of delivery attempts for reliability tracking"
    
    t.timestamp "delivered_at",
                null: true,
                comment: "Timestamp when message was successfully delivered"
    
    t.timestamp "expires_at",
                null: true,
                comment: "Message expiration timestamp for automatic cleanup"
    
    # Security and audit fields
    t.string "message_id",
             limit: 255,
             null: true,
             comment: "Unique message identifier for deduplication and tracking"
    
    t.string "sender_identifier",
             limit: 255,
             null: true,
             comment: "Sender identification for audit trails"
    
    t.jsonb "metadata",
            null: true,
            comment: "Flexible metadata storage for application-specific data"
    
    # Performance monitoring fields
    t.decimal "processing_time_ms",
              precision: 10,
              scale: 3,
              null: true,
              comment: "Message processing time in milliseconds for performance analytics"
    
    # Partitioning support for massive scale
    t.integer "partition_key",
              null: false,
              comment: "Partitioning key for horizontal scaling across multiple database nodes"
    
    # Advanced constraint validation
    t.check_constraint "priority IN ('low', 'normal', 'high', 'critical')",
                       name: "valid_priority_levels"
    
    t.check_constraint "payload_size > 0 AND payload_size <= 536870912",
                       name: "valid_payload_size"
    
    t.check_constraint "delivery_attempts >= 0",
                       name: "non_negative_delivery_attempts"
    
    t.check_constraint "compression_ratio >= 0 AND compression_ratio <= 100",
                       name: "valid_compression_ratio"
    
    # Ensure message_id uniqueness for deduplication
    t.index ["message_id"], 
            name: "index_solid_cable_messages_on_message_id",
            unique: true,
            where: "message_id IS NOT NULL"
    
    # Optimized composite indexes for common query patterns
    t.index ["channel", "created_at"],
            name: "index_solid_cable_messages_on_channel_and_created_at",
            order: { created_at: :desc }
    
    t.index ["channel_hash", "created_at"],
            name: "index_solid_cable_messages_on_channel_hash_and_created_at",
            order: { created_at: :desc }
    
    # Partition-aware indexing for massive scale
    t.index ["partition_key", "created_at"],
            name: "index_solid_cable_messages_on_partition_and_created_at",
            order: { created_at: :desc }
    
    # Priority-based processing indexes
    t.index ["priority", "created_at"],
            name: "index_solid_cable_messages_on_priority_and_created_at",
            order: { created_at: :asc },
            where: "priority IN ('high', 'critical')"
    
    # Expiration-based cleanup index
    t.index ["expires_at"],
            name: "index_solid_cable_messages_on_expires_at",
            where: "expires_at IS NOT NULL"
    
    # Message type analytics index
    t.index ["message_type", "created_at"],
            name: "index_solid_cable_messages_on_message_type_and_created_at",
            order: { created_at: :desc }
    
    # Delivery tracking indexes
    t.index ["delivered_at"],
            name: "index_solid_cable_messages_on_delivered_at",
            where: "delivered_at IS NOT NULL"
    
    t.index ["delivery_attempts", "created_at"],
            name: "index_solid_cable_messages_on_delivery_attempts_and_created_at",
            order: { delivery_attempts: :desc, created_at: :asc }
    
    # Metadata JSONB GIN index for flexible querying
    t.index "metadata",
            name: "index_solid_cable_messages_on_metadata",
            using: :gin
    
    # Partial index for undelivered messages (most common query)
    t.index ["channel", "created_at"],
            name: "index_solid_cable_messages_undelivered",
            order: { created_at: :asc },
            where: "delivered_at IS NULL"
    
    # Performance monitoring index
    t.index ["processing_time_ms"],
            name: "index_solid_cable_messages_on_processing_time",
            order: { processing_time_ms: :desc },
            where: "processing_time_ms IS NOT NULL"
  end
  
  # Enable Row Level Security if using PostgreSQL
  execute <<-SQL.squish
    ALTER TABLE solid_cable_messages ENABLE ROW LEVEL SECURITY;
  SQL
  
  # Create advanced partitioning (requires PostgreSQL 11+)
  execute <<-SQL.squish
    -- Monthly partitioning for time-based data lifecycle management
    CREATE TABLE IF NOT EXISTS solid_cable_messages_y2024m10
    PARTITION OF solid_cable_messages
    FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');
    
    CREATE TABLE IF NOT EXISTS solid_cable_messages_y2024m11
    PARTITION OF solid_cable_messages
    FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
    
    CREATE TABLE IF NOT EXISTS solid_cable_messages_y2024m12
    PARTITION OF solid_cable_messages
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');
    
    -- Default partition for future months
    CREATE TABLE IF NOT EXISTS solid_cable_messages_default
    PARTITION OF solid_cable_messages DEFAULT;
  SQL
  
  # Create performance monitoring view
  execute <<-SQL.squish
    CREATE OR REPLACE VIEW solid_cable_message_stats AS
    SELECT
      DATE_TRUNC('hour', created_at) as hour,
      message_type,
      priority,
      COUNT(*) as message_count,
      AVG(payload_size) as avg_payload_size,
      AVG(compression_ratio) as avg_compression_ratio,
      AVG(processing_time_ms) as avg_processing_time_ms,
      SUM(CASE WHEN delivered_at IS NOT NULL THEN 1 ELSE 0 END) as delivered_count,
      SUM(CASE WHEN delivered_at IS NULL THEN 1 ELSE 0 END) as pending_count
    FROM solid_cable_messages
    WHERE created_at >= NOW() - INTERVAL '24 hours'
    GROUP BY DATE_TRUNC('hour', created_at), message_type, priority
    ORDER BY hour DESC, message_type, priority;
  SQL
  
  # Create automated cleanup function for expired messages
  execute <<-SQL.squish
    CREATE OR REPLACE FUNCTION cleanup_expired_messages()
    RETURNS INTEGER AS $$
    DECLARE
      deleted_count INTEGER;
    BEGIN
      DELETE FROM solid_cable_messages
      WHERE expires_at IS NOT NULL
        AND expires_at < NOW();
      
      GET DIAGNOSTICS deleted_count = ROW_COUNT;
      RETURN deleted_count;
    END;
    $$ LANGUAGE plpgsql;
  SQL
end
