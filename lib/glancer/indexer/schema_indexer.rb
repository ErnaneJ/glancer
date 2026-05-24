# frozen_string_literal: true

module Glancer
  module Indexer
    module SchemaIndexer
      module_function

      def index!
        Glancer::Utils::Logger.info("Indexer::SchemaIndexer", "Starting schema indexing...")

        schema_file = Rails.root.join("db/schema.rb")

        unless File.exist?(schema_file)
          Glancer::Utils::Logger.warn("Indexer::SchemaIndexer", "Schema file not found at: #{schema_file}")
          return []
        end

        Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Reading schema file from: #{schema_file}")

        content = File.read(schema_file)
        Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Read #{content.bytesize} bytes from schema file")

        eager_load_models!

        chunks = split_into_chunks(content)
        Glancer::Utils::Logger.info("Indexer::SchemaIndexer", "Found #{chunks.size} table definition(s) in schema")

        indexed_chunks = chunks.map do |chunk|
          table_name = extract_table_name(chunk)
          if table_name
            Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Indexed table: #{table_name}")
            enriched = chunk + model_associations_block(table_name)
            {
              content: enriched,
              source_type: "schema",
              source_path: "#{schema_file}##{table_name}"
            }
          else
            Glancer::Utils::Logger.warn("Indexer::SchemaIndexer", "Could not extract table name from chunk")
            nil
          end
        end.compact

        fk_chunk = extract_foreign_keys(content, schema_file)
        indexed_chunks << fk_chunk if fk_chunk

        inflections_chunk = extract_inflections
        indexed_chunks << inflections_chunk if inflections_chunk

        Glancer::Utils::Logger.info("Indexer::SchemaIndexer",
                                    "Completed schema indexing. Total indexed chunks: #{indexed_chunks.size}")

        indexed_chunks
      rescue StandardError => e
        Glancer::Utils::Logger.error("Indexer::SchemaIndexer", "Schema indexing failed: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error, "Schema indexing failed: #{e.message}"
      end

      def eager_load_models!
        Rails.application.eager_load!
        Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Models eager-loaded for association reflection")
      rescue StandardError => e
        Glancer::Utils::Logger.warn("Indexer::SchemaIndexer", "Could not eager-load models: #{e.message}")
      end

      def find_model_for_table(table_name)
        candidates = ActiveRecord::Base.descendants.select do |model|
          !model.abstract_class? &&
            !model.name&.start_with?("Glancer::") &&
            model.table_name == table_name
        end
        return nil if candidates.empty?

        candidates.find { |m| m.superclass.abstract_class? || m.superclass == ActiveRecord::Base } || candidates.first
      rescue StandardError
        nil
      end

      def model_associations_block(table_name)
        model = find_model_for_table(table_name)
        return "" unless model

        assocs = model.reflect_on_all_associations
        return "" if assocs.empty?

        lines = assocs.filter_map do |assoc|
          format_association(assoc)
        rescue StandardError
          nil
        end
        return "" if lines.empty?

        "\n\n# ActiveRecord Associations (#{model.name}):\n#{lines.join("\n")}"
      end

      def format_association(assoc)
        parts = ["  #{assoc.macro} :#{assoc.name}"]
        opts = ["class_name: \"#{assoc.class_name}\""]

        fk = assoc.foreign_key.to_s
        opts << "foreign_key: \"#{fk}\"" if fk.present?
        opts << "through: :#{assoc.options[:through]}" if assoc.options[:through].present?
        opts << "polymorphic: true" if assoc.options[:polymorphic]
        opts << "as: :#{assoc.options[:as]}" if assoc.options[:as].present?
        opts << "source: :#{assoc.options[:source]}" if assoc.options[:source].present?
        opts << "dependent: :#{assoc.options[:dependent]}" if assoc.options[:dependent].present?

        "#{parts.join} (#{opts.join(", ")})"
      end

      def extract_inflections
        inflections_file = Rails.root.join("config/initializers/inflections.rb")
        return nil unless File.exist?(inflections_file)

        raw = File.read(inflections_file)
        return nil unless raw.lines.any? { |l| l.strip.match?(/\binflect\.\w/) }

        Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Found custom inflections, adding as schema chunk")
        {
          content: "# Custom Rails Inflections\n# These control plural/singular model name mapping.\n\n#{raw.strip}",
          source_type: "schema",
          source_path: inflections_file.to_s
        }
      rescue StandardError => e
        Glancer::Utils::Logger.warn("Indexer::SchemaIndexer", "Could not read inflections: #{e.message}")
        nil
      end

      def split_into_chunks(schema_text)
        schema_text.split(/^  create_table /).map do |chunk|
          next if chunk.strip.empty?

          "create_table #{chunk.strip}"
        end.compact
      end

      def extract_table_name(chunk)
        chunk[/create_table ["']?([a-zA-Z0-9_]+)["']?/, 1]
      end

      def extract_foreign_keys(schema_text, schema_file)
        lines = schema_text.lines.select { |l| l.strip.start_with?("add_foreign_key") }
        return nil if lines.empty?

        relationships = lines.filter_map do |line|
          # add_foreign_key "orders", "users", column: "user_id"
          # add_foreign_key "order_items", "orders"
          m = line.match(/add_foreign_key ["'](\w+)["'],\s*["'](\w+)["'](?:.*column:\s*["'](\w+)["'])?/)
          next unless m

          child_table = m[1]
          parent_table = m[2]
          column = m[3] || "#{parent_table.singularize}_id"
          "#{child_table}.#{column} → #{parent_table}.id"
        end

        return nil if relationships.empty?

        content = "# Foreign Key Relationships\n#{relationships.join("\n")}"
        Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Extracted #{relationships.size} foreign key(s)")

        {
          content: content,
          source_type: "schema",
          source_path: "#{schema_file}#foreign_keys"
        }
      end
    end
  end
end
