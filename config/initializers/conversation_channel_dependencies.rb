# frozen_string_literal: true

# ConversationChannel Dependencies Configuration
# Hexagonal Architecture: Dependency Injection Setup

ConversationChannel.configure_dependencies(
  message_service: MessageService::Core.instance,
  conversation_service: ConversationService::Core.instance,
  security_service: SecurityService::Core.instance,
  rate_limiter: RateLimitingService::Adaptive.instance,
  circuit_breaker: CircuitBreaker::Resilient.instance,
  telemetry_service: TelemetryService::Comprehensive.instance
)