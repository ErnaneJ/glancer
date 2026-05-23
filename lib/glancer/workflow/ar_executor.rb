# frozen_string_literal: true

module Glancer
  module Workflow
    class ARExecutor
      def self.execute(code, original_question: nil, attempt: 1, message_id: nil)
        Glancer::Utils::Logger.info("Workflow::ARExecutor", "Executing AR expression (Attempt ##{attempt})...")

        run_id = SecureRandom.uuid

        begin
          result = nil
          Glancer::Utils::Transaction.make do |connection|
            Glancer::Workflow::Executor.apply_statement_timeout(connection)
            raw = evaluate(code)
            result = normalize(raw)
            raise ActiveRecord::Rollback
          end

          Glancer::Audit.create!(
            question: original_question,
            code: code,
            code_type: "activerecord",
            adapter: Glancer.configuration.resolved_adapter,
            run_id: run_id,
            executed_at: Time.current,
            message_id: message_id
          )

          result
        rescue StandardError => e
          if attempt >= 3
            Glancer::Utils::Logger.error("Workflow::ARExecutor",
                                         "Final failure after #{attempt} attempts: #{e.message}")
            return { error: true, message: e.message, last_code: code }
          end

          Glancer::Utils::Logger.warn("Workflow::ARExecutor",
                                      "AR Error (Attempt ##{attempt}): #{e.message}. Requesting correction...")

          fixed_code = Glancer::Workflow::Builder.fix_ar_code(code, e.message)
          execute(fixed_code, original_question: original_question, attempt: attempt + 1, message_id: message_id)
        end
      end

      def self.evaluate(code)
        TOPLEVEL_BINDING.eval(code) # rubocop:disable Security/Eval
      end

      def self.normalize(result)
        case result
        when ActiveRecord::Relation
          result.to_a.map { |r| r.respond_to?(:attributes) ? r.attributes : { "value" => r } }
        when Array
          result.map do |item|
            if item.respond_to?(:attributes)
              item.attributes
            elsif item.is_a?(Hash)
              item.stringify_keys
            else
              { "value" => item }
            end
          end
        when Hash
          [result.stringify_keys]
        when Numeric, String
          [{ "result" => result }]
        when NilClass
          []
        else
          [{ "result" => result.inspect }]
        end
      end
    end
  end
end
