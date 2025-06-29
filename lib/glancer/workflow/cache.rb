module Glancer
  module Workflow
    class Cache
      @@store = {} # Using a simple hash for in-memory storage (@TODO redis / DB - i don't know now)

      def self.fetch(question)
        entry = @@store[question]
        return nil unless entry

        if expired?(entry)
          @@store.delete(question)
          return nil
        end

        entry
      end

      def self.write(question, result)
        @@store[question] = result.merge(cached_at: Time.current)
      end

      def self.clear
        @@store.clear
      end

      def self.expired?(entry)
        ttl = Glancer.configuration&.workflow_cache_ttl || 5.minutes
        Time.current - entry[:cached_at] > ttl
      end
    end
  end
end
