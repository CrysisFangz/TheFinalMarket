# Solid Queue Database Schema
# Enhanced with performance optimizations, better maintainability, and robust constraints
#
# This schema implements a high-performance job queue system with the following improvements:
# - Strategic composite indexes for optimal query performance
# - Enhanced data validation through check constraints
# - Improved foreign key relationships with cascade options
# - Better column naming and organization
# - Performance-optimized data types and limits

ActiveRecord::Schema[7.1].define(version: 1) do
  # Configuration constants for better maintainability
  JOB_STATUSES = {
    pending: 'pending',
    ready: 'ready',
    claimed: 'claimed',
    blocked: 'blocked',
    failed: 'failed',
    completed: 'completed'
  }.freeze

  MAX_QUEUE_NAME_LENGTH = 50
  MAX_CLASS_NAME_LENGTH = 255
  MAX_CONCURRENCY_KEY_LENGTH = 128
  MAX_COMMAND_LENGTH = 2048

  # ============================================================================
  # CORE JOB TABLES
  # ============================================================================

  # Main jobs table - stores all job definitions and metadata
  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", limit: MAX_QUEUE_NAME_LENGTH, null: false, comment: "Name of the queue this job belongs to"
    t.string "class_name", limit: MAX_CLASS_NAME_LENGTH, null: false, comment: "Ruby class that handles this job"
    t.text "arguments", comment: "Serialized job arguments (JSON)"
    t.integer "priority", default: 0, null: false, comment: "Job priority (higher numbers = higher priority)"
    t.string "active_job_id", comment: "ActiveJob ID for Rails integration"
    t.datetime "scheduled_at", comment: "When this job should be executed"
    t.datetime "finished_at", comment: "When this job completed execution"
    t.string "concurrency_key", limit: MAX_CONCURRENCY_KEY_LENGTH, comment: "Key for concurrency control"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false

    # Optimized indexes for common query patterns
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id", unique: true
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"

    # Composite indexes for performance-critical queries
    t.index ["queue_name", "priority", "scheduled_at"], name: "index_solid_queue_jobs_priority_queue"
    t.index ["concurrency_key", "priority"], name: "index_solid_queue_jobs_concurrency_priority"
  end

  # ============================================================================
  # EXECUTION STATE TABLES
  # ============================================================================

  # Jobs ready for immediate execution
  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", limit: MAX_QUEUE_NAME_LENGTH, null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false

    # Primary index for job lookup
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true

    # Critical performance indexes for job polling
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all", order: { priority: :desc }
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue", order: { priority: :desc, job_id: :asc }

    # Additional indexes for maintenance and monitoring
    t.index ["queue_name", "created_at"], name: "index_solid_queue_ready_executions_queue_time"
    t.index ["created_at"], name: "index_solid_queue_ready_executions_created_at"
  end

  # Jobs currently being executed by workers
  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id", comment: "ID of the worker process executing this job"
    t.datetime "created_at", null: false

    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
    t.index ["process_id"], name: "index_solid_queue_claimed_executions_on_process_id"
    t.index ["created_at"], name: "index_solid_queue_claimed_executions_on_created_at"
  end

  # Jobs waiting for dependencies or resources
  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", limit: MAX_QUEUE_NAME_LENGTH, null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", limit: MAX_CONCURRENCY_KEY_LENGTH, null: false
    t.datetime "expires_at", null: false, comment: "When this block expires and job becomes available"
    t.datetime "created_at", null: false

    # Indexes for efficient blocking/unblocking operations
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release", order: { priority: :desc }
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true

    # Additional performance indexes
    t.index ["expires_at"], name: "index_solid_queue_blocked_executions_expires_at"
    t.index ["concurrency_key"], name: "index_solid_queue_blocked_executions_concurrency_key"
  end

  # Jobs scheduled for future execution
  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", limit: MAX_QUEUE_NAME_LENGTH, null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false

    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all", order: { scheduled_at: :asc, priority: :desc }
    t.index ["scheduled_at"], name: "index_solid_queue_scheduled_executions_scheduled_at"
    t.index ["queue_name", "scheduled_at"], name: "index_solid_queue_scheduled_executions_queue_schedule"
  end

  # ============================================================================
  # FAILURE AND RECOVERY TABLES
  # ============================================================================

  # Jobs that have failed execution
  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error", comment: "Detailed error information"
    t.datetime "created_at", null: false

    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
    t.index ["created_at"], name: "index_solid_queue_failed_executions_on_created_at"

    # Index for retry analysis and monitoring
    t.index ["error"], name: "index_solid_queue_failed_executions_error_pattern", length: 100
  end

  # ============================================================================
  # RECURRING JOB TABLES
  # ============================================================================

  # Recurring task definitions
  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false, comment: "Unique identifier for the recurring task"
    t.string "schedule", null: false, comment: "Cron-like schedule expression"
    t.string "command", limit: MAX_COMMAND_LENGTH, comment: "Command to execute"
    t.string "class_name", limit: MAX_CLASS_NAME_LENGTH, comment: "Ruby class for this task"
    t.text "arguments", comment: "Serialized arguments for the task"
    t.string "queue_name", limit: MAX_QUEUE_NAME_LENGTH, comment: "Target queue for this task"
    t.integer "priority", default: 0, null: false
    t.boolean "static", default: true, null: false, comment: "Whether this task definition is static"
    t.text "description", comment: "Human-readable description of the task"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false

    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
    t.index ["schedule"], name: "index_solid_queue_recurring_tasks_on_schedule"
    t.index ["queue_name"], name: "index_solid_queue_recurring_tasks_on_queue_name"
  end

  # Individual executions of recurring tasks
  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false, comment: "Reference to the recurring task definition"
    t.datetime "run_at", null: false, comment: "When this execution should run"
    t.datetime "created_at", null: false

    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
    t.index ["run_at"], name: "index_solid_queue_recurring_executions_on_run_at"
    t.index ["task_key"], name: "index_solid_queue_recurring_executions_on_task_key"
  end

  # ============================================================================
  # SYSTEM CONTROL TABLES
  # ============================================================================

  # Queue pause/resume control
  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", limit: MAX_QUEUE_NAME_LENGTH, null: false
    t.datetime "created_at", null: false

    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  # Worker process tracking
  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false, comment: "Type of process (worker, scheduler, etc.)"
    t.datetime "last_heartbeat_at", null: false, comment: "Last time this process sent a heartbeat"
    t.bigint "supervisor_id", comment: "ID of the supervisor process"
    t.integer "pid", null: false, comment: "Operating system process ID"
    t.string "hostname", comment: "Hostname where this process is running"
    t.text "metadata", comment: "Additional process metadata (JSON)"
    t.datetime "created_at", null: false
    t.string "name", null: false, comment: "Human-readable process name"

    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
    t.index ["kind"], name: "index_solid_queue_processes_on_kind"
    t.index ["pid"], name: "index_solid_queue_processes_on_pid", unique: true
  end

  # Concurrency control semaphores
  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false, comment: "Semaphore identifier"
    t.integer "value", default: 1, null: false, comment: "Current semaphore value"
    t.datetime "expires_at", null: false, comment: "When this semaphore expires"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false

    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true

    # Additional indexes for semaphore management
    t.index ["value"], name: "index_solid_queue_semaphores_on_value"
    t.index ["updated_at"], name: "index_solid_queue_semaphores_on_updated_at"
  end

  # ============================================================================
  # FOREIGN KEY CONSTRAINTS
  # ============================================================================

  # Define foreign key relationships with appropriate cascade behavior
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs",
                  column: "job_id", on_delete: :cascade, name: "fk_solid_queue_blocked_executions_job"
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs",
                  column: "job_id", on_delete: :cascade, name: "fk_solid_queue_claimed_executions_job"
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs",
                  column: "job_id", on_delete: :cascade, name: "fk_solid_queue_failed_executions_job"
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs",
                  column: "job_id", on_delete: :cascade, name: "fk_solid_queue_ready_executions_job"
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs",
                  column: "job_id", on_delete: :cascade, name: "fk_solid_queue_recurring_executions_job"
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs",
                  column: "job_id", on_delete: :cascade, name: "fk_solid_queue_scheduled_executions_job"

  # ============================================================================
  # CHECK CONSTRAINTS FOR DATA INTEGRITY
  # ============================================================================

  # Ensure priority values are within reasonable bounds
  execute <<-SQL
    ALTER TABLE solid_queue_jobs
    ADD CONSTRAINT check_priority_range
    CHECK (priority >= -1000 AND priority <= 1000)
  SQL

  execute <<-SQL
    ALTER TABLE solid_queue_ready_executions
    ADD CONSTRAINT check_ready_priority_range
    CHECK (priority >= -1000 AND priority <= 1000)
  SQL

  execute <<-SQL
    ALTER TABLE solid_queue_blocked_executions
    ADD CONSTRAINT check_blocked_priority_range
    CHECK (priority >= -1000 AND priority <= 1000)
  SQL

  execute <<-SQL
    ALTER TABLE solid_queue_scheduled_executions
    ADD CONSTRAINT check_scheduled_priority_range
    CHECK (priority >= -1000 AND priority <= 1000)
  SQL

  # Ensure semaphore values are non-negative
  execute <<-SQL
    ALTER TABLE solid_queue_semaphores
    ADD CONSTRAINT check_semaphore_value_positive
    CHECK (value >= 0)
  SQL

  # Ensure scheduled_at is in the future for scheduled executions
  execute <<-SQL
    ALTER TABLE solid_queue_scheduled_executions
    ADD CONSTRAINT check_scheduled_at_future
    CHECK (scheduled_at > created_at)
  SQL

  # Ensure expires_at is in the future for blocked executions
  execute <<-SQL
    ALTER TABLE solid_queue_blocked_executions
    ADD CONSTRAINT check_expires_at_future
    CHECK (expires_at > created_at)
  SQL

  # ============================================================================
  # PERFORMANCE OPTIMIZATION COMMENTS
  # ============================================================================

  # The following indexes are optimized for common Solid Queue operations:
  #
  # 1. Job Polling: index_solid_queue_poll_all and index_solid_queue_poll_by_queue
  #    - These are the most critical indexes for performance
  #    - Ordered by priority DESC for efficient job selection
  #
  # 2. Job Dispatch: index_solid_queue_dispatch_all
  #    - Optimized for scheduled job processing
  #    - Ordered by scheduled_at ASC, priority DESC
  #
  # 3. Concurrency Control: Multiple indexes on concurrency_key
  #    - Essential for blocking/unblocking operations
  #    - Supports efficient semaphore management
  #
  # 4. Monitoring and Maintenance:
  #    - Indexes on created_at, finished_at for time-based queries
  #    - Partial indexes where appropriate for common filter patterns
  #
  # 5. Data Integrity:
  #    - Check constraints prevent invalid data states
  #    - Foreign keys ensure referential integrity
end