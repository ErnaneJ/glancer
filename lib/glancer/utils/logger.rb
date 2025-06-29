module Glancer
  module Utils
    class Logger
      COLORS = {
        debug: "\e[36m", # cyan
        info: "\e[32m",  # green
        warn: "\e[33m",  # yellow
        error: "\e[31m", # red
        reset: "\e[0m"
      }.freeze

      EMOJIS = {
        debug: "🔍",
        info: "✅",
        warn: "⚠️",
        error: "❌"
      }.freeze

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
          emoji = EMOJIS[level] || ""
          color = COLORS[level] || ""
          reset = COLORS[:reset]

          timestamp = Time.current.strftime("%Y-%m-%d %H:%M:%S")
          line = "[#{timestamp}] [Glancer::#{tag}] #{emoji} #{message}"

          if Glancer.configuration.log_output_path
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
