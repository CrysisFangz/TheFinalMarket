# app/concerns/retryable.rb
# Extracted as a concern for reusability across the application
module Retryable
  extend ActiveSupport::Concern

  DEFAULT_RETRY_OPTIONS = {
    max_attempts: 3,
    base_delay: 0.1,
    max_delay: 2.0,
    exponential_base: 2,
    jitter: true
  }.freeze

  def with_retry(options = {}, &block)
    retry_options = DEFAULT_RETRY_OPTIONS.merge(options)

    attempt = 0
    delay = retry_options[:base_delay]

    begin
      attempt += 1
      return block.call
    rescue => e
      if attempt < retry_options[:max_attempts] && retryable_error?(e)
        sleep delay

        # Apply exponential backoff
        delay = [delay * retry_options[:exponential_base], retry_options[:max_delay]].min

        # Add jitter to prevent thundering herd
        if retry_options[:jitter]
          jitter_amount = delay * 0.1 * rand
          delay += jitter_amount
        end

        retry
      else
        raise e
      end
    end
  end

  def with_retry_async(options = {}, &block)
    # For async operations, we could use a job queue
    # For now, just execute synchronously
    with_retry(options, &block)
  end

  private

  def retryable_error?(error)
    # Define which errors are worth retrying
    retryable_errors = [
      ActiveRecord::StatementTimeout,
      ActiveRecord::ConnectionTimeoutError,
      ActiveRecord::ConnectionNotEstablished,
      ActiveRecord::StatementInvalid,
      PG::ConnectionBad,
      PG::UndefinedTable,
      Timeout::Error,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Errno::ECONNRESET,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Redis::TimeoutError,
      Redis::ConnectionError
    ]

    retryable_errors.any? { |error_class| error.is_a?(error_class) }
  end
end