module Glancer
  module Workflow
    class Cache
      @@store = {} # Using a simple hash for in-memory storage (@TODO redis / DB - i don't know now)

      def self.fetch(question)
        Glancer::Utils::Logger.info("Workflow::Cache", "Attempting to fetch cache for question: #{question.inspect}")

        entry = @@store[question]
        return nil unless entry

        if expired?(entry)
          Glancer::Utils::Logger.info("Workflow::Cache", "Cache entry expired for question: #{question.inspect}")
          @@store.delete(question)
          return nil
        end

        Glancer::Utils::Logger.info("Workflow::Cache", "Cache hit for question: #{question.inspect}")
        Glancer::Utils::Logger.debug("Workflow::Cache", "Cached at: #{entry[:cached_at]}")
        entry
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Cache", "Failed to fetch from cache: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::Cache", "Backtrace:\n#{e.backtrace.join("\n")}")
        nil
      end

      def self.write(question, result)
        Glancer::Utils::Logger.info("Workflow::Cache", "Writing result to cache for question: #{question.inspect}")
        @@store[question] = result.merge(cached_at: Time.current)
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Cache", "Failed to write to cache: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::Cache", "Backtrace:\n#{e.backtrace.join("\n")}")
      end

      def self.clear
        Glancer::Utils::Logger.info("Workflow::Cache", "Clearing all cache entries")
        @@store.clear
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Cache", "Failed to clear cache: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::Cache", "Backtrace:\n#{e.backtrace.join("\n")}")
      end

      def self.expired?(entry)
        ttl = Glancer.configuration&.workflow_cache_ttl || 5.minutes
        age = Time.current - entry[:cached_at]
        Glancer::Utils::Logger.debug("Workflow::Cache", "Checking expiration: age=#{age.round(2)}s, ttl=#{ttl.inspect}")
        age > ttl
      rescue StandardError
        true
      end
    end
  end
end
