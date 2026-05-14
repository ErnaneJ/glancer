module Glancer
  class SchemaController < Glancer::ApplicationController
    layout "glancer/application"

    def show
      @chats = Glancer::Chat.order(created_at: :desc)
      connection = ActiveRecord::Base.connection
      @tables = connection.tables.sort.filter_map do |table_name|
        next if %w[schema_migrations ar_internal_metadata].include?(table_name)

        columns = connection.columns(table_name).map do |col|
          { name: col.name, type: col.sql_type, null: col.null, default: col.default }
        end

        fks = begin
          connection.foreign_keys(table_name).map do |fk|
            { from_column: fk.column, to_table: fk.to_table, to_column: fk.primary_key }
          end
        rescue StandardError
          []
        end

        { name: table_name, columns: columns, foreign_keys: fks }
      end

    end
  end
end
