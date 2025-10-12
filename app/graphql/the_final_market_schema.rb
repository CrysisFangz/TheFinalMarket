# frozen_string_literal: true

class TheFinalMarketSchema < GraphQL::Schema
  mutation(Types::MutationType)
  query(Types::QueryType)
  subscription(Types::SubscriptionType)

  # Use batch loading to solve N+1 queries
  use GraphQL::Batch

  # Limit query depth to prevent abuse
  max_depth 15

  # Limit query complexity
  max_complexity 300

  # Enable persisted queries for better caching
  use GraphQL::Execution::Interpreter
  use GraphQL::Analysis::AST

  # Error handling
  rescue_from(ActiveRecord::RecordNotFound) do |err, obj, args, ctx, field|
    raise GraphQL::ExecutionError, "#{field.type.unwrap.graphql_name} not found"
  end

  rescue_from(ActiveRecord::RecordInvalid) do |err, obj, args, ctx, field|
    raise GraphQL::ExecutionError, err.record.errors.full_messages.join(', ')
  end

  # Rate limiting
  def self.execute(query_str = nil, **kwargs)
    context = kwargs[:context] || {}
    
    # Check rate limit
    if context[:current_user]
      rate_limit_key = "graphql:#{context[:current_user].id}"
      count = Rails.cache.read(rate_limit_key) || 0
      
      if count > 100 # 100 requests per minute
        raise GraphQL::ExecutionError, "Rate limit exceeded"
      end
      
      Rails.cache.write(rate_limit_key, count + 1, expires_in: 1.minute)
    end
    
    super
  end
end

