# frozen_string_literal: true

module Glancer
  module Utils
    module RateLimitRetry
      RATE_LIMIT_PATTERNS = [
        /rate.?limit/i,
        /quota.?exceed/i,
        /exceeded.?your.?current.?quota/i,
        /too.?many.?request/i,
        /resource.?exhausted/i,
        /\b429\b/
      ].freeze

      RETRY_AFTER_PATTERN = /retry.?in\s+([0-9]+(?:\.[0-9]+)?)\s*s/i

      def self.with_retry(context:, max_retries: nil, base_delay: nil)
        max_retries ||= Glancer.configuration.max_llm_retries
        base_delay  ||= Glancer.configuration.llm_retry_delay
        attempt = 0

        begin
          yield
        rescue StandardError => e
          raise unless rate_limit_error?(e) && attempt < max_retries

          attempt += 1
          delay = parse_retry_after(e.message) || (base_delay * (2**(attempt - 1)))
          Glancer::Utils::Logger.warn(
            context,
            "Rate limit hit (attempt #{attempt}/#{max_retries}). Retrying in #{delay.ceil}s..."
          )
          sleep(delay)
          retry
        end
      end

      def self.rate_limit_error?(error)
        RATE_LIMIT_PATTERNS.any? { |p| error.message.match?(p) } ||
          error.class.name.match?(/rate.?limit/i)
      end
      private_class_method :rate_limit_error?

      def self.parse_retry_after(message)
        m = message.match(RETRY_AFTER_PATTERN)
        m && m[1].to_f.positive? ? m[1].to_f : nil
      end
      private_class_method :parse_retry_after
    end
  end
end
