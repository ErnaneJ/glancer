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
        TOPLEVEL_BINDING.eval(code)
      end

      def self.normalize(result)
        rows = case result
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
                 return normalize_hash(result.stringify_keys)
               when Numeric, String
                 return [{ "result" => result }]
               when NilClass
                 return []
               else
                 # Single AR model object (e.g. from .first / .find)
                 return [{ "result" => result.inspect }] unless result.respond_to?(:attributes)

                 [result.attributes]

               end

        drop_all_nil_columns(rows)
      end

      # Removes columns where every row has a nil value (e.g. `id` when using
      # .select("col1, col2") — AR still populates id: nil on the model objects).
      def self.drop_all_nil_columns(rows)
        return rows if rows.empty?

        nil_cols = rows.first.keys.select { |k| rows.all? { |r| r[k].nil? } }
        return rows if nil_cols.empty?

        rows.map { |r| r.except(*nil_cols) }
      end

      # Hashes from .group().count/sum/etc. map {group_value => aggregate} and must
      # be rendered as rows. Hashes where values are mixed types (e.g. model
      # attributes) are kept as a single row.
      def self.normalize_hash(hash)
        if hash.values.all? { |val| val.is_a?(Numeric) }
          hash.map { |key, val| { "key" => key.to_s, "value" => val } }
        else
          [hash]
        end
      end
    end
  end
end
