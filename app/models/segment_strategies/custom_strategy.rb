# frozen_string_literal: true

module SegmentStrategies
  # Strategy for custom SQL-based segmentation
  class CustomStrategy < BaseStrategy
    def user_ids_for_segment
      return [] unless criteria['sql_query'].present?

      begin
        # Validate SQL query for security (basic check)
        validate_sql_query(criteria['sql_query'])

        user_ids = User.connection.select_values(criteria['sql_query'])

        Rails.logger.info(
          "CustomStrategy executed successfully",
          segment_id: segment.id,
          segment_name: segment.name,
          result_count: user_ids.count
        )

        user_ids
      rescue StandardError => e
        Rails.logger.error(
          "CustomStrategy SQL execution failed",
          segment_id: segment.id,
          segment_name: segment.name,
          error: e.message
        )

        raise ArgumentError, "Invalid SQL query in custom segment: #{e.message}"
      end
    end

    private

    # Basic SQL validation to prevent dangerous queries
    def validate_sql_query(sql)
      dangerous_keywords = [
        'DROP', 'DELETE', 'UPDATE', 'INSERT', 'ALTER', 'CREATE',
        'TRUNCATE', 'EXEC', 'EXECUTE', 'MERGE'
      ]

      sql_upper = sql.upcase
      found_dangerous = dangerous_keywords.select { |keyword| sql_upper.include?(keyword) }

      return if found_dangerous.empty?

      raise ArgumentError, "SQL query contains potentially dangerous keywords: #{found_dangerous.join(', ')}"
    end
  end
end