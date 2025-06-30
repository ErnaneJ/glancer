module Glancer
  module Utils
    class Logger
      VERBOSITY_LEVELS = {
        none: -1,
        info: 1,
        debug: 2
      }.freeze

      COLORS = {
        debug: "\e[36m",
        info: "\e[32m",
        warn: "\e[33m",
        error: "\e[31m",
        reset: "\e[0m"
      }.freeze

      # EMOJIS = {
      #   debug: "🔍",
      #   info: "✅",
      #   warn: "⚠️",
      #   error: "❌"
      # }.freeze

      class << self
        def debug(tag, message)
          write(:debug, tag, message)
        end

        def info(tag, message)
          write(:info, tag, message)
        end

        def warn(tag, message)
          write(:warn, tag, message)
        end

        def error(tag, message)
          write(:error, tag, message)
        end

        private

        def write(level, tag, message)
          verbosity = begin
            Glancer.configuration.log_verbosity.to_sym
          rescue StandardError
            :info
          end

          # Always allow warn and error
          return if %i[info debug].include?(level) &&
                    VERBOSITY_LEVELS[level] > VERBOSITY_LEVELS[verbosity]

          # emoji = EMOJIS[level] || ""
          color = COLORS[level] || ""
          reset = COLORS[:reset]

          timestamp = Time.current.strftime("%Y-%m-%d %H:%M:%S")
          # line = "#{emoji} [#{timestamp}] [Glancer::#{tag}] #{message}"
          line = "[#{timestamp}] [Glancer::#{tag}] #{message}"

          if Glancer.configuration&.log_output_path
            File.open(Glancer.configuration.log_output_path, "a") { |f| f.puts(line) }
          elsif defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
            Rails.logger.send(level, line)
          else
            puts("#{color}#{line}#{reset}")
          end
        end
      end
    end
  end
end
